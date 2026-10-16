package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/peer"
	"google.golang.org/grpc/status"
	"log"
	"net"
	"os"
	"os/signal"
	"python_go_grpc/server/api"
	"syscall"
	"time"
)

func logging(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
	start := time.Now()
	res, err := handler(ctx, req)
	p, _ := peer.FromContext(ctx)
	log.Printf("peer=%v method=%s status=%s duration=%s", p, info.FullMethod, status.Code(err), time.Since(start))
	return res, err
}
func main() {
	cert, err := tls.LoadX509KeyPair("certs/server.pem", "certs/server-key.pem")
	if err != nil {
		log.Fatal(err)
	}
	pem, err := os.ReadFile("certs/ca.pem")
	if err != nil {
		log.Fatal(err)
	}
	pool := x509.NewCertPool()
	if !pool.AppendCertsFromPEM(pem) {
		log.Fatal("invalid CA")
	}
	config := &tls.Config{MinVersion: tls.VersionTLS12, Certificates: []tls.Certificate{cert}, ClientCAs: pool, ClientAuth: tls.RequireAndVerifyClientCert}
	secure := grpc.NewServer(grpc.Creds(credentials.NewTLS(config)), grpc.UnaryInterceptor(logging))
	plain := grpc.NewServer(grpc.UnaryInterceptor(logging))
	for addr, s := range map[string]*grpc.Server{"127.0.0.1:8443": secure, "127.0.0.1:50051": plain} {
		listener, err := net.Listen("tcp", addr)
		if err != nil {
			log.Fatal(err)
		}
		api.RegisterDiceServiceServer(s, api.NewServer())
		log.Printf("gRPC listening on %s", addr)
		go func(s *grpc.Server, l net.Listener) {
			if err := s.Serve(l); err != nil {
				log.Print(err)
			}
		}(s, listener)
	}
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop
	secure.GracefulStop()
	plain.GracefulStop()
}
