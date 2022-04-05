//go:build linux
// +build linux

package keylogger

import (
	"fmt"
	"musicplayer/songs"
	"os"

	"github.com/godbus/dbus/v5"
)

func ListenInput() {

	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		fmt.Fprintln(os.Stderr, "Failed to connect to session bus:", err)
		os.Exit(1)
	}
	defer conn.Close()

	for _, v := range []string{"signal"} {
		call := conn.BusObject().Call("org.freedesktop.DBus.AddMatch", 0,
			"eavesdrop='true',type='"+v+"'")
		if call.Err != nil {
			fmt.Fprintln(os.Stderr, "Failed to add match:", call.Err)
			os.Exit(1)
		}
	}

	c := make(chan *dbus.Message, 10)
	conn.Eavesdrop(c)
	for v := range c {
		if len(v.Body) > 0 && v.Body[0] == "mediacontrol" {

			//What happened
			switch v.Body[1] {
			case "nextmedia":
				songs.NextSong()
			case "previousmedia":
				songs.PreviousSong()
			case "playpausemedia":
				songs.PlayPauseSong()
			}
		}
	}
}
