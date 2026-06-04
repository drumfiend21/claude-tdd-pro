package runner

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/drumfiend21/claude-tdd-pro/runner-go/internal/spec"
)

func TestRun_PassingSpec(t *testing.T) {
	exit := 0
	s := &spec.Spec{
		Name:    "passing spec returns exit 0 and stderr ok",
		Command: "echo ok 1>&2",
		Expect: spec.Expectation{
			ExitCode:       &exit,
			StderrContains: []string{"ok"},
		},
		Path: "test-spec.json",
	}
	r := New()
	r.CacheDir = t.TempDir()
	results := r.Run([]*spec.Spec{s})
	if !results[0].Passed {
		t.Errorf("expected pass; got fail: stderr=%q", results[0].Stderr)
	}
}

func TestRun_FailingSpec(t *testing.T) {
	exit := 0
	s := &spec.Spec{
		Name:    "failing spec returns exit 1 contradicting expect",
		Command: "exit 1",
		Expect:  spec.Expectation{ExitCode: &exit},
		Path:    "test-spec-fail.json",
	}
	r := New()
	r.CacheDir = t.TempDir()
	results := r.Run([]*spec.Spec{s})
	if results[0].Passed {
		t.Errorf("expected fail; got pass")
	}
}

func TestRun_ParallelCorrectness(t *testing.T) {
	exit := 0
	specs := make([]*spec.Spec, 20)
	for i := range specs {
		specs[i] = &spec.Spec{
			Name:    "concurrent spec for parallelism correctness check",
			Command: "echo ok 1>&2",
			Expect: spec.Expectation{
				ExitCode:       &exit,
				StderrContains: []string{"ok"},
			},
			Path: filepath.Join("spec", "concurrent.json"),
		}
	}
	r := New()
	r.CacheDir = t.TempDir()
	results := r.Run(specs)
	pass := 0
	for _, res := range results {
		if res.Passed {
			pass++
		}
	}
	if pass != 20 {
		t.Errorf("expected 20 passes from parallel run; got %d", pass)
	}
}

func TestCache_HitOnSecondRun(t *testing.T) {
	exit := 0
	s := &spec.Spec{
		Name:    "cache hit verification on identical second invocation",
		Command: "echo ok 1>&2",
		Expect: spec.Expectation{
			ExitCode:       &exit,
			StderrContains: []string{"ok"},
		},
		Path: "test-cache.json",
	}
	r := New()
	r.CacheDir = t.TempDir()
	r.Run([]*spec.Spec{s}) // populate cache
	results := r.Run([]*spec.Spec{s})
	if !results[0].CacheHit {
		t.Errorf("second run should have hit cache")
	}
}

func TestFormatResults_MatchesBashRunner(t *testing.T) {
	s := &spec.Spec{
		Name: "x",
		Path: filepath.Join("evals", "specs", "test-spec.json"),
	}
	results := []Result{{Spec: s, Passed: true}}
	out := FormatResults(results, false, 4)
	if !contains(out, "✓ test-spec") {
		t.Errorf("missing checkmark line; got %q", out)
	}
	if !contains(out, "Results: 1 passed, 0 failed") {
		t.Errorf("missing results line; got %q", out)
	}
}

func TestFormatResults_StatsLine(t *testing.T) {
	results := []Result{}
	out := FormatResults(results, true, 4)
	if !contains(out, "STATS: workers=4") {
		t.Errorf("missing stats line; got %q", out)
	}
}

func contains(s, sub string) bool {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}

// Helper to avoid pulling in another import for the tests above.
var _ = os.TempDir
