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

### Installation
I recommend installing using [Vundle](https://github.com/gmarik/vundle):

Add `Bundle 'takac/vim-spotifysearch'` to your `~/.vimrc` and then:

* either within Vim: `:BundleInstall`
* or in your shell: `vim +BundleInstall +qall`

#### Other Installation Methods
*  [Pathogen](https://github.com/tpope/vim-pathogen)
    *  `git clone https://github.com/takac/vim-spotifysearch ~/.vim/bundle/vim-spotifysearch`
*  [Neobundle](https://github.com/Shougo/neobundle.vim)
    *  `NeoBundle 'takac/vim-spotifysearch'`
*  Manual
    *  Copy the files into your `~/.vim` directory
