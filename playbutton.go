package main

import (
	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/widget"
)

type PlayButton struct {
	specialTapped func(*PlayButton)
	songnum       int

	*widget.Button
}

func NewPlayButton(name string, num int, a func(*PlayButton)) *PlayButton {
	button := &PlayButton{
		Button:        widget.NewButton(name, func() {}),
		specialTapped: a,
		songnum:       num,
	}

	return button
}

func (b *PlayButton) Tapped(event *fyne.PointEvent) {

	if b.Disabled() {
		return
	}

	b.Button.Tapped(event)
	if b.specialTapped != nil {
		b.specialTapped(b)
	}
}
