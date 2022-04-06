package main

import (
	"fmt"
	"os"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"

	"musicplayer/keylogger"
	"musicplayer/player"
	"musicplayer/songs"
)

func main() {

	//path := "/mnt/127C43E17C43BE6B/OneDrive/Musik"
	path := "C:/OneDrive/Musik"

	//Create app, window and layout
	app := app.New()
	window := app.NewWindow("really bad MP3 player")
	songs.InitializeList()

	//Create bottom bar
	bottombar := container.NewHBox()

	//Volume up
	bottombar.Add(
		widget.NewButtonWithIcon("", theme.VolumeUpIcon(), func() {
			if player.Volume < 2.0 {
				player.Volume += 0.1
			}
			fmt.Println("Volume", player.Volume)
		}),
	)

	//Volume down
	bottombar.Add(
		widget.NewButtonWithIcon("", theme.VolumeDownIcon(), func() {
			if player.Volume > 0.0 {
				player.Volume -= 0.1
			}
			fmt.Println("Volume", player.Volume)
		}),
	)

	//Repeat
	bottombar.Add(
		widget.NewButtonWithIcon("", theme.MediaReplayIcon(), func() {
			player.Looping = !player.Looping
			fmt.Println("Looping", player.Looping)
		}),
	)

	//Shuffle
	bottombar.Add(
		widget.NewButtonWithIcon("", theme.ContentCutIcon(), songs.Shuffle),
	)

	//Play/pause
	songs.ButtonPlayPause = widget.NewButtonWithIcon("", theme.MediaPauseIcon(), songs.PlayPauseSong)
	bottombar.Add(songs.ButtonPlayPause)

	//Create sidemenu
	searchbar := widget.NewEntry()
	searchbar.SetPlaceHolder("Search..")
	searchbar.OnSubmitted = func(s string) {
		songs.Songlist = songs.GetFilesSearch(strings.ToLower(s))
		songs.SongContainer.ScrollToTop()
		songs.SongContainer.Refresh()
		songs.SongContainer.ScrollToTop()
	}
	searchButton := widget.NewButtonWithIcon("", theme.SearchIcon(), func() {
		searchbar.OnSubmitted(searchbar.Text)
		songs.SongContainer.ScrollToTop()
		songs.SongContainer.Refresh()
		songs.SongContainer.ScrollToTop()
	})
	sidemenu := container.NewVBox(
		container.NewBorder(
			nil, nil, nil, searchButton,
			searchbar,
		),
	)

	contentMain := container.NewHSplit(sidemenu, songs.SongContainer)
	fullWindow := container.NewBorder(nil, bottombar, nil, nil, contentMain)

	//Get all songs
	allsongs, err := songs.GetFiles(path)
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

	//Add songs to allsongs array
	for _, f := range allsongs {
		s := songs.NewSong(f.Name(), path+"/"+f.Name())
		songs.Allsongs = append(songs.Allsongs, s)
	}

	songs.Songlist = songs.Allsongs
	songs.UpdateSongOrder()
	songs.SongContainer.Refresh()
	go keylogger.ListenInput()

	//Um
	window.SetContent(fullWindow)
	window.Resize(fyne.NewSize(640, 480))
	window.ShowAndRun()
}
