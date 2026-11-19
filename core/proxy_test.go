package core

import (
	"testing"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
)

func TestAdapterAsUnwrapsParsedProxy(t *testing.T) {
	direct := outbound.NewDirect()
	proxy := adapter.NewProxy(outbound.NewAutoCloseProxyAdapter(direct))

	got, ok := adapterAs[*outbound.Direct](proxy)
	if !ok {
		t.Fatal("adapterAs did not unwrap the parsed proxy adapter")
	}
	if got != direct {
		t.Fatalf("adapterAs returned %p, want %p", got, direct)
	}
}
