//go:build windows
// +build windows

package keylogger

import (
	"musicplayer/songs"
	"time"

	kl "github.com/kindlyfire/go-keylogger"
)

func ListenInput() {

	l := kl.NewKeylogger()
	for {
		switch k := l.GetKey().Keycode; k {
		case 176:
			songs.NextSong()
		case 177:
			songs.PreviousSong()
		case 179:
			songs.PlayPauseSong()
		}

		//Sleepies
		time.Sleep(time.Second / 60)
	}
}
