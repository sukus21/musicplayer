package player

import (
	"io"
	"os"

	"github.com/hajimehoshi/go-mp3"
	"github.com/hajimehoshi/oto"
)

var Context *oto.Context = nil
var Player *oto.Player = nil

func Run(path string) error {

	if Context != nil {
		Context.Close()
		Context = nil
	}

	//Open file
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()

	//Create decoder
	d, err := mp3.NewDecoder(f)
	if err != nil {
		return err
	}

	if Context == nil {
		Context, err = oto.NewContext(d.SampleRate(), 2, 2, 8192)
		if err != nil {
			return nil
		}
	}

	Player = Context.NewPlayer()
	defer Player.Close()

	if _, err := io.Copy(Player, d); err != nil {
		return err
	}

	return nil
}

type repeatPlayer struct {
}
