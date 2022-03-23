package main

import (
	"fmt"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/widget"
)

func main() {

	//Create app and window
	app := app.New()
	window := app.NewWindow("amogus")

	content := container.New(layout.NewVBoxLayout())
	content.Add(addSong("song 1", 0))
	content.Add(addSong("song 2", 1))
	content.Add(addSong("song 3", 2))
	content.Add(addSong("song 1", 3))
	content.Add(addSong("song 2", 4))
	content.Add(addSong("song 3", 5))
	content.Add(addSong("song 1", 6))
	content.Add(addSong("song 2", 7))
	content.Add(addSong("song 3", 8))

	window.SetContent(content)
	window.Resize(fyne.NewSize(640, 480))
	window.ShowAndRun()
}

func addSong(name string, num int) *fyne.Container {
	content := container.New(layout.NewHBoxLayout())

	content.Add(NewPlayButton(">", num, playButton))
	content.Add(widget.NewButton("<", PlayButtonBoring))
	content.Add(widget.NewLabel(name))
	return content
}

func PlayButtonBoring() {
	fmt.Println("play button boring")
}

func playButton(b *PlayButton) {
	fmt.Println("play button", b.songnum)
}
