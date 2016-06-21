Vim Spotify Search
==================

A plugin to allow you to search and play tracks from spotify right inside Vim.

Make sure you have spotify running externally, then in Vim:

    :Spotify yeezus

Yields a new window with the search results

    Track                    Artist             Release Year      Album
    Bound 2                  Kanye West         2013              Yeezus
    Black Skinhead           Kanye West         2013              Yeezus
    Black Skinhead           Kanye West         2013              Yeezus
    Bound 2                  Kanye West         2013              Yeezus
    Blood On The Leaves      Kanye West         2013              Yeezus
    New Slaves               Kanye West         2013              Yeezus
    Blood On The Leaves      Kanye West         2013              Yeezus
    Hold My Liquor           Kanye West         2013              Yeezus
    I Am A God               God                2013              Yeezus
    I'm In It                Kanye West         2013              Yeezus
    .
    .
    .

Just hit enter to have the song played by spotify.

<img src="screenshot.png" height="80%" width="80%" alt="screenshot"/>

### Region Configuration

To filter the results appropriate to your region add the line below to your
`.vimrc` with the correct country code.

    let g:spotify_country_code = 'GB'

#### PlayPause, Next, Prev Keys

For linux operating systems with dbus, you can map specific keys to
play/pause, next and previous.

    let g:spotify_prev_key = "<F9>"
    let g:spotify_playpause_key = "<F10>"
    let g:spotify_next_key = "<F11>"

These mappings will only work inside the spotify list buffer.

### Installation

#### Checking if your installation of vim is compatible

This plugin isn't compatible with installations of vim on versions below 7.4.

To check your version of vim run:
    vim --version

If your installation isn't compatible then you need to update your version

#### Installing the plugin

I recommend installing using [Vundle](https://github.com/gmarik/vundle):

Add `Bundle 'takac/vim-spotifysearch'` to your `~/.vimrc` and then:

* either within Vim: `:BundleInstall`
* or in your shell: `vim +BundleInstall +qall`

##### Other Installation Methods
*  [Pathogen](https://github.com/tpope/vim-pathogen)
    *  `git clone https://github.com/takac/vim-spotifysearch ~/.vim/bundle/vim-spotifysearch`
*  [Neobundle](https://github.com/Shougo/neobundle.vim)
    *  `NeoBundle 'takac/vim-spotifysearch'`
*  Manual
    *  Copy the files into your `~/.vim` directory

#### Installing 'spotipy'

In order for this plugin to work, you will need to install ['spotipy'](https://github.com/plamere/spotipy).

[Please visit spotipy's readme on their repo for instructions on installing it](https://github.com/plamere/spotipy#installation)



