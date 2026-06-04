// Fowler's discipline: shipped behind tests. Every public function in
// this package gets a unit test before the bash runner's parsing is
// migrated.
package spec

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoad_ValidSpec(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "test.json")
	content := `{
		"name": "test spec with sufficiently long name",
		"command": "echo ok 1>&2",
		"setup": [],
		"expect": {"exit_code": 0, "stderr_contains": ["ok"]}
	}`
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	s, err := Load(path)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if s.Name == "" || s.Command == "" {
		t.Errorf("spec fields not populated")
	}
	if s.Path != path {
		t.Errorf("Path not preserved: got %q want %q", s.Path, path)
	}
}

func TestLoad_MalformedJSON(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "bad.json")
	if err := os.WriteFile(path, []byte("{not valid"), 0644); err != nil {
		t.Fatal(err)
	}
	if _, err := Load(path); err == nil {
		t.Errorf("Load should reject malformed JSON")
	}
}

func TestValidate_ShortNameRejected(t *testing.T) {
	s := &Spec{Name: "short", Command: "x", Expect: Expectation{}}
	if err := s.Validate(); err == nil {
		t.Errorf("short name should be rejected")
	}
}

func TestValidate_NoAssertionsRejected(t *testing.T) {
	s := &Spec{
		Name:    "long enough name for the validator",
		Command: "true",
		Expect:  Expectation{},
	}
	if err := s.Validate(); err == nil {
		t.Errorf("no assertions should be rejected")
	}
}

func TestValidate_AcceptsCanonicalShape(t *testing.T) {
	exit := 0
	s := &Spec{
		Name:    "behaves correctly when given canonical inputs",
		Command: "echo ok 1>&2",
		Expect: Expectation{
			ExitCode:       &exit,
			StderrContains: []string{"ok"},
		},
	}
	if err := s.Validate(); err != nil {
		t.Errorf("canonical spec rejected: %v", err)
	}
}
