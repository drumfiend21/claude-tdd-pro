// Package spec defines the canonical spec schema and JSON unmarshal logic.
// Fowler's discipline: parse once at the boundary, work with typed values
// internally. The bash runner's "field parsed lazily on demand" pattern
// is precisely where the env-var-positional bug from CL-420 lived.
package spec

import (
	"encoding/json"
	"fmt"
	"os"
)

// Expectation declares what the runner must verify after invoking
// the spec command. Mirrors the bash runner's expect{} block.
type Expectation struct {
	ExitCode       *int     `json:"exit_code,omitempty"`
	StdoutContains []string `json:"stdout_contains,omitempty"`
	StderrContains []string `json:"stderr_contains,omitempty"`
}

// Spec is a single eval spec.
type Spec struct {
	Name    string      `json:"name"`
	Command string      `json:"command"`
	Setup   []string    `json:"setup,omitempty"`
	Expect  Expectation `json:"expect"`

	// Internal fields populated by the loader.
	Path string `json:"-"`
}

// Load parses a JSON spec file. Returns a typed Spec with the path
// preserved for diagnostic output.
func Load(path string) (*Spec, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("spec.Load: %w", err)
	}
	var s Spec
	if err := json.Unmarshal(raw, &s); err != nil {
		return nil, fmt.Errorf("spec.Load %s: %w", path, err)
	}
	s.Path = path
	return &s, nil
}

// Validate enforces the minimum spec contract per CONTRIBUTING.md.
// Hermetic, state-asserting, behavior-named, ≥20 char name.
func (s *Spec) Validate() error {
	if len(s.Name) < 20 {
		return fmt.Errorf("spec name too short (<20 chars): %q", s.Name)
	}
	if s.Command == "" {
		return fmt.Errorf("spec command is empty")
	}
	if s.Expect.ExitCode == nil &&
		len(s.Expect.StdoutContains) == 0 &&
		len(s.Expect.StderrContains) == 0 {
		return fmt.Errorf("spec has no assertions")
	}
	return nil
}
