package api

import (
	"context"
	"math/rand"
	"sync"
	"time"
)

const Dots = 6

type Server struct {
	UnimplementedDiceServiceServer
	mu  sync.Mutex
	rnd *rand.Rand
}

func NewServer() *Server {
	return &Server{rnd: rand.New(rand.NewSource(time.Now().UnixNano()))}
}
func (s *Server) RollDie(ctx context.Context, req *RollDieRequest) (*RollDieResponse, error) {
	s.mu.Lock()
	value := s.rnd.Intn(Dots) + 1
	s.mu.Unlock()
	return &RollDieResponse{Value: int32(value)}, nil
}
