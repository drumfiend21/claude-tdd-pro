// Command tdd-pro-runner is the Go implementation of the rubric runner.
// Replaces rubric/runner.sh (per ADR-0001 §rollback). Emits the same
// `Results: N passed, M failed` envelope and STATS line so CI / hooks
// / LSP need no changes to consume.
//
// Build:   cd runner-go && go build -o ../bin/tdd-pro-runner .
// Run:     bin/tdd-pro-runner --specs evals/specs/
// Filter:  bin/tdd-pro-runner --specs evals/specs/ --filter "cl414-Q-1"
// Stats:   bin/tdd-pro-runner --specs evals/specs/ --stats
package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/drumfiend21/claude-tdd-pro/runner-go/internal/runner"
	"github.com/drumfiend21/claude-tdd-pro/runner-go/internal/spec"
)

func main() {
	specsDir := flag.String("specs", "evals/specs", "spec directory")
	filter := flag.String("filter", "", "only run specs whose basename contains this substring")
	stats := flag.Bool("stats", false, "emit STATS line after Results")
	workers := flag.Int("workers", 4, "parallel workers")
	md := flag.String("md", "", "emit JSONL findings to this path (per --md contract)")
	quiet := flag.Bool("quiet", false, "no findings → exit 0; any finding → exit 2 (Stop-hook contract)")
	severityFloor := flag.String("severity-floor", "", "gate exit on findings at or above this severity (P0|P1|P2)")
	flag.Parse()

	entries, err := os.ReadDir(*specsDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "tdd-pro-runner: read specs dir: %v\n", err)
		os.Exit(2)
	}

	var specs []*spec.Spec
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		if *filter != "" && !strings.Contains(e.Name(), *filter) {
			continue
		}
		path := filepath.Join(*specsDir, e.Name())
		s, err := spec.Load(path)
		if err != nil {
			fmt.Fprintf(os.Stderr, "  ! %s: %v\n", e.Name(), err)
			continue
		}
		specs = append(specs, s)
	}

	r := runner.New()
	r.Workers = *workers
	results := r.Run(specs)
	fmt.Print(runner.FormatResults(results, *stats, *workers))

	fail := 0
	for _, res := range results {
		if !res.Passed {
			fail++
		}
	}

	// --md JSONL emission (Stop-hook downstream consumer contract).
	if *md != "" {
		if err := runner.EmitJSONL(results, *md); err != nil {
			fmt.Fprintf(os.Stderr, "tdd-pro-runner: --md emit failed: %v\n", err)
		}
	}

	// --severity-floor / --quiet gating (Stop-hook exit semantics).
	if *severityFloor != "" {
		blocking := runner.CountAtOrAbove(results, *severityFloor)
		if blocking > 0 {
			fmt.Fprintf(os.Stderr, "tdd-pro-runner: gated on %d findings at severity floor=%s\n",
				blocking, *severityFloor)
			os.Exit(1)
		}
	}
	if *quiet {
		if fail > 0 {
			os.Exit(2)
		}
		os.Exit(0)
	}

	if fail > 0 {
		os.Exit(1)
	}
}
