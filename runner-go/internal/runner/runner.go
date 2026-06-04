// Package runner executes specs in parallel with a content-addressed cache.
// Mirrors the bash runner's contract (Results line, --stats output) so
// downstream consumers (CI, hooks, LSP) need no changes to switch.
package runner

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	"github.com/drumfiend21/claude-tdd-pro/runner-go/internal/spec"
)

// Result of executing a single spec.
type Result struct {
	Spec      *spec.Spec
	Passed    bool
	ExitCode  int
	Stdout    string
	Stderr    string
	CacheHit  bool
}

// Runner executes a batch of specs concurrently.
type Runner struct {
	Workers   int
	UseCache  bool
	CacheDir  string
	TreeSHA   string // populated from substrate hash by the caller
}

// New constructs a Runner with sensible defaults.
func New() *Runner {
	return &Runner{
		Workers:  4,
		UseCache: true,
		CacheDir: filepath.Join(os.Getenv("HOME"), ".cache", "claude-tdd-pro"),
	}
}

// Run executes every spec and returns the results in input order.
func (r *Runner) Run(specs []*spec.Spec) []Result {
	results := make([]Result, len(specs))
	sem := make(chan struct{}, r.Workers)
	var wg sync.WaitGroup
	for i, s := range specs {
		wg.Add(1)
		sem <- struct{}{}
		go func(i int, s *spec.Spec) {
			defer wg.Done()
			defer func() { <-sem }()
			results[i] = r.runOne(s)
		}(i, s)
	}
	wg.Wait()
	return results
}

func (r *Runner) runOne(s *spec.Spec) Result {
	res := Result{Spec: s}
	if r.UseCache {
		if hit, cached := r.cacheLookup(s); hit {
			cached.CacheHit = true
			return *cached
		}
	}
	cmd := exec.Command("bash", "-c", s.Command)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	cmd.Env = os.Environ()
	err := cmd.Run()
	if exitErr, ok := err.(*exec.ExitError); ok {
		res.ExitCode = exitErr.ExitCode()
	} else if err == nil {
		res.ExitCode = 0
	} else {
		res.ExitCode = -1
	}
	res.Stdout = stdout.String()
	res.Stderr = stderr.String()
	res.Passed = r.evaluate(s, &res)
	if r.UseCache {
		_ = r.cacheStore(s, &res)
	}
	return res
}

func (r *Runner) evaluate(s *spec.Spec, res *Result) bool {
	if s.Expect.ExitCode != nil && *s.Expect.ExitCode != res.ExitCode {
		return false
	}
	for _, sub := range s.Expect.StdoutContains {
		if !strings.Contains(res.Stdout, sub) {
			return false
		}
	}
	for _, sub := range s.Expect.StderrContains {
		if !strings.Contains(res.Stderr, sub) {
			return false
		}
	}
	return true
}

func (r *Runner) cacheKey(s *spec.Spec) string {
	h := sha256.New()
	h.Write([]byte(s.Command))
	h.Write([]byte(r.TreeSHA))
	for _, sub := range s.Expect.StdoutContains {
		h.Write([]byte(sub))
	}
	for _, sub := range s.Expect.StderrContains {
		h.Write([]byte(sub))
	}
	return hex.EncodeToString(h.Sum(nil))[:16]
}

func (r *Runner) cacheLookup(s *spec.Spec) (bool, *Result) {
	p := filepath.Join(r.CacheDir, r.cacheKey(s))
	if _, err := os.Stat(p); err != nil {
		return false, nil
	}
	return true, &Result{Spec: s, Passed: true, ExitCode: 0}
}

func (r *Runner) cacheStore(s *spec.Spec, res *Result) error {
	if !res.Passed {
		return nil
	}
	if err := os.MkdirAll(r.CacheDir, 0755); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(r.CacheDir, r.cacheKey(s)), []byte("ok"), 0644)
}

// FormatResults emits the bash-runner-compatible output format so
// CI / hooks / LSP need no changes to consume Go-runner output.
func FormatResults(results []Result, withStats bool, workers int) string {
	var sb strings.Builder
	pass, fail := 0, 0
	cacheHits, cacheMisses := 0, 0
	for _, r := range results {
		if r.Passed {
			pass++
			sb.WriteString(fmt.Sprintf("  ✓ %s\n", baseName(r.Spec.Path)))
		} else {
			fail++
			sb.WriteString(fmt.Sprintf("  ✗ %s\n", baseName(r.Spec.Path)))
		}
		if r.CacheHit {
			cacheHits++
		} else {
			cacheMisses++
		}
	}
	sb.WriteString(fmt.Sprintf("\nResults: %d passed, %d failed\n", pass, fail))
	if withStats {
		sb.WriteString(fmt.Sprintf("    STATS: workers=%d cache=1 cache_hits=%d cache_misses=%d\n",
			workers, cacheHits, cacheMisses))
	}
	return sb.String()
}

func baseName(path string) string {
	b := filepath.Base(path)
	return strings.TrimSuffix(b, ".json")
}

// EmitJSONL writes one finding per failing result to path, as JSONL.
// Mirrors the bash runner's --md format so downstream consumers
// (Stop hook, PR-comment bot, IDE diagnostics) need no changes.
func EmitJSONL(results []Result, path string) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	for _, r := range results {
		if r.Passed {
			continue
		}
		line := fmt.Sprintf(
			`{"spec":%q,"exit_code":%d,"stderr":%q,"stdout":%q}`+"\n",
			baseName(r.Spec.Path), r.ExitCode,
			truncate(r.Stderr, 200), truncate(r.Stdout, 200),
		)
		if _, err := f.WriteString(line); err != nil {
			return err
		}
	}
	return nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}

// CountAtOrAbove returns the number of failing results whose
// severity (as parsed from the spec's expect block or default P1)
// meets or exceeds the floor (P0 > P1 > P2).
func CountAtOrAbove(results []Result, floor string) int {
	// Severity ordering: P0 is most severe, P2 least.
	rank := map[string]int{"P0": 0, "P1": 1, "P2": 2}
	floorRank, ok := rank[floor]
	if !ok {
		// Unknown floor: count all failures.
		floorRank = 99
	}
	count := 0
	for _, r := range results {
		if r.Passed {
			continue
		}
		// Default severity P1 for specs without explicit annotation.
		// Future: parse from spec.Severity field.
		specRank := 1
		if specRank <= floorRank {
			count++
		}
	}
	return count
}
