//go:build linux
// +build linux

package network

import (
	"github.com/pkg/errors"
	"github.com/vishvananda/netlink"
)

const (
	MinMTUIPv4 uint32 = 576  // RFC 791
	MinMTUIPv6 uint32 = 1280 // RFC 8200
	MaxMTU     uint32 = 65536
)

// GetDefaultMTU gets the mtu of the default route.
func GetDefaultMTU() (int, error) {
	// Get the interface with the default route
	// TODO(cdc) handle v6-only nodes
	routes, err := netlink.RouteList(nil, netlink.FAMILY_ALL)
	if err != nil {
		return 0, errors.Wrapf(err, "could not list routes")
	}
	if len(routes) == 0 {
		return 0, errors.Errorf("got no routes")
	}

	const maxMTU = 65536
	mtu := maxMTU + 1
	for _, route := range routes {
		// Skip non-default routes
		if route.Dst != nil {
			continue
		}
		link, err := netlink.LinkByIndex(route.LinkIndex)
		if err != nil {
			return 0, errors.Wrapf(err, "could not retrieve link id %d", route.LinkIndex)
		}

		newmtu := link.Attrs().MTU
		if newmtu > 0 && newmtu < mtu {
			mtu = newmtu
		}
	}
	if mtu > maxMTU {
		return 0, errors.Errorf("unable to determine MTU")
	}

	return mtu, nil
}
