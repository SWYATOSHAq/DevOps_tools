package api
import (
 "context"
 "sync"
 "testing"
)
func TestConcurrentRolls(t *testing.T) {
 s := NewServer()
 var wg sync.WaitGroup
 for i:=0; i<100; i++ {
  wg.Add(1)
  go func(){
   defer wg.Done()
   r,err:=s.RollDie(context.Background(), &RollDieRequest{})
   if err!=nil || r.Value<1 || r.Value>6 { t.Errorf("invalid result: %v %v",r,err) }
  }()
 }
 wg.Wait()
}
