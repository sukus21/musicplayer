package player

import (
	"bytes"

	"github.com/hajimehoshi/ebiten/v2/audio"
	"github.com/hajimehoshi/ebiten/v2/audio/mp3"
	raudio "github.com/hajimehoshi/ebiten/v2/examples/resources/audio"
)

var context *audio.Context = nil
var current *audio.Player = nil

func Run(path string) error {

	_ = path

	//Create context if it doesn't exist
	if context == nil {
		context = audio.NewContext(48000)
	}

	//Stop currently playing song
	if current != nil {
		current.Close()
	}

	//Open file
	//f, err := os.ReadFile(path)
	f := raudio.Ragtime_mp3
	//if err != nil {
	//	return err
	//}

	//Create decoder
	s := bytes.NewReader(f)
	d, err := mp3.DecodeWithSampleRate(context.SampleRate(), s)
	if err != nil {
		return err
	}
	//fmt.Println(d.SampleRate())
	current, err = context.NewPlayer(d)
	if err != nil {
		return err
	}
	current.Play()

	return nil
}
