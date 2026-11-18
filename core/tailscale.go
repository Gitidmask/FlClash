package core

import (
	"context"
	"fmt"
	"time"

	"github.com/metacubex/mihomo/adapter/outbound"
)

const tailscaleOperationTimeout = 40 * time.Second

func resolveTailscale(name string) (*outbound.Tailscale, error) {
	proxy := lookupProxy(name)
	if proxy == nil {
		return nil, &MethodError{
			Code:    "not_found",
			Message: fmt.Sprintf("proxy %q was not found", name),
		}
	}
	tailscale, ok := adapterAs[*outbound.Tailscale](proxy)
	if !ok {
		return nil, &MethodError{
			Code:    "invalid_proxy",
			Message: fmt.Sprintf("proxy %q is not Tailscale", name),
		}
	}
	return tailscale, nil
}

func handleTailscaleStatus(params NameParams) (TailscaleStatusResult, error) {
	tailscale, err := resolveTailscale(params.Name)
	if err != nil {
		return TailscaleStatusResult{}, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), tailscaleOperationTimeout)
	defer cancel()
	status, err := tailscale.Status(ctx)
	if err != nil {
		return TailscaleStatusResult{}, err
	}
	return TailscaleStatusResult{
		BackendState:   status.BackendState,
		AuthURL:        status.AuthURL,
		Hostname:       status.Hostname,
		ControlURL:     status.ControlURL,
		InterfaceName:  status.InterfaceName,
		MagicDNSSuffix: status.MagicDNSSuffix,
		Addresses:      status.Addresses,
		Health:         status.Health,
		Online:         status.Online,
	}, nil
}

func handleTailscaleLogin(params NameParams) error {
	tailscale, err := resolveTailscale(params.Name)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), tailscaleOperationTimeout)
	defer cancel()
	return tailscale.Login(ctx)
}

func handleTailscaleLogout(params NameParams) error {
	tailscale, err := resolveTailscale(params.Name)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), tailscaleOperationTimeout)
	defer cancel()
	return tailscale.Logout(ctx)
}
