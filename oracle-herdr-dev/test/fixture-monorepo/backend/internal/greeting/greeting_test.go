package greeting

import "testing"

func TestNormalize(t *testing.T) {
	cases := map[string]string{
		"":        "world",
		"  bob  ": "bob",
		"alice":   "alice",
	}
	for in, want := range cases {
		if got := Normalize(in); got != want {
			t.Errorf("Normalize(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestServiceCounts(t *testing.T) {
	s := NewService("")
	s.Greet("a")
	g := s.Greet("b")
	if g.Count != 2 {
		t.Fatalf("count = %d, want 2", g.Count)
	}
	if g.App != "fixture" {
		t.Fatalf("app = %q, want fixture", g.App)
	}
	if g.Message != "hello, b" {
		t.Fatalf("message = %q", g.Message)
	}
}
