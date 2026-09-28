// Package greeting builds greeting messages. It exists so there is something
// to jump to (gd), find references for (gr) and rename (<leader>rn).
package greeting

import (
	"fmt"
	"strings"
	"sync"
)

// Greeting is the JSON payload returned by /api/greet.
type Greeting struct {
	Message string `json:"message"`
	App     string `json:"app"`
	Count   int    `json:"count"`
}

// Service produces greetings and counts how many it has produced.
type Service struct {
	app   string
	mu    sync.Mutex
	count int
}

// NewService returns a Service labelled with app (defaults to "fixture").
func NewService(app string) *Service {
	if app == "" {
		app = "fixture"
	}
	return &Service{app: app}
}

// Greet returns a greeting for name.
func (s *Service) Greet(name string) Greeting {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.count++
	return Greeting{
		Message: fmt.Sprintf("hello, %s", Normalize(name)),
		App:     s.app,
		Count:   s.count,
	}
}

// Normalize trims name and falls back to "world" when it is empty.
func Normalize(name string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		return "world"
	}
	return name
}
