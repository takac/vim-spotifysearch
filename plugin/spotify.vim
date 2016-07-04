" Author: Tom Cammann
" Version: 0.5

if &cp || version < 700
    finish
end

function! s:GetCountryCode()
    if !exists("g:spotify_country_code")
        return 'ANY'
        " TODO: Add after testing and user feedback
        " -------
        " let geoip = s:Curl("http://freegeoip.net/json/")
        " let country_code = matchlist(geoip, '\v"country_code":"([^"]+)"')
        " if len(country_code) >= 2 && len(country_code[1]) > 0
        "     let g:spotify_country_code = country_code[1]
        " else
        "     let g:spotify_country_code = 'ANY'
        " endif
    endif
    return g:spotify_country_code
endfunction

function! s:GetOS()
    if has("win32") || has("win32unix")
        return "Windows"
    elseif has("unix")
        let os = s:SystemCallWrapper("uname -s")
        if has("mac") || has("macunix") ||  os =~ "Darwin" || os =~ "Mac"
            return "Mac"
        else
            return "Linux"
        endif
    else
        throw "Platform unsupported"
    endif
endfunction

function! s:SystemCallWrapper(command)
    let result = system(a:command)
    if v:shell_error
        throw "Non zero exit code [" . v:shell_error . "] from: " . a:command
    endif
    return result
endfunction

function! MacUriOpener(uri, ...)
    let in_context = a:0 > 0 ? ' in context "' . a:1 . '"' : ''
    call s:SystemCallWrapper("osascript -e 'tell application \"Spotify\"'"
                \ . " -e 'play track \"" . a:uri . "\"" . in_context . "' -e 'end tell'")
endfunction

function! LinuxUriOpener(uri, ...)
    " TODO: Update to use DBUS
    call s:SystemCallWrapper("spotify " . a:uri)
endfunction

function! WindowsUriOpener(uri, ...)
    call s:SystemCallWrapper("explorer " . a:uri)
endfunction

function! FollowMapping()
    call b:FollowDict.follow(line("."), virtcol("."))
endfunction

function! s:OpenWindow()
    if exists("t:bufferName") && bufnr(t:bufferName) > -1
        let n = bufwinnr(t:bufferName)
        if n > -1
            exec n . " wincmd w"
        else
            topleft new
            exec "buffer " . t:bufferName
        endif
    else
        let t:bufferName = "spotify_list"
        topleft new
        silent! exec "edit " . t:bufferName
    endif
    setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap modifiable
endfunction

" Mappings
function! s:BufferTrackSearchMappings()
    nnoremap <silent> <buffer> <CR> :silent call FollowMapping()<CR>
    nnoremap <silent> <buffer> <2-LeftMouse> :call FollowMapping()<CR>
    nnoremap <silent> <buffer> q <C-W>q
    if exists("g:spotify_prev_key")
        exec 'nnoremap <silent> <buffer> ' . g:spotify_prev_key . ' :call system("dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Prev")<CR>'
    endif
    if exists("g:spotify_next_key")
        exec 'nnoremap <silent> <buffer> ' . g:spotify_next_key . ' :call system("dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Next")<CR>'
    endif
    if exists("g:spotify_playpause_key")
        exec 'nnoremap <silent> <buffer> ' . g:spotify_playpause_key . ' :call system("dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlayPause")<CR>'
    endif
    " exec 'nnoremap <silent> <buffer> s :call SpotifyOpenTrackUri("spotify:search:' . s:search_term . '")<CR>'
endfunction

" Highlighting
function! s:LoadSyntaxHightlighting()
    syn match trackOne '.*\S\s$' display
    syn match trackTwo '.*\s\s$' display
    syn match headers 'Track\s*Artist\s*Album'
    hi def link trackOne Type
    hi def link trackTwo PreProc
    hi def link headers Comment
endfunction

" TODO: check if uri and open with spotify if uri
function! SpotifyTrackSearch(track)
    if len(a:track) == 0
        call s:OpenWindow()
        return
    endif
    if ! has_key(s:cache.track_search, a:track)
        python << EOL
import spotipy
import vim
s = spotipy.Spotify()
results = s.search(vim.eval("a:track"), type="track")
results['tracks']['next'] = 'None'
results['tracks']['previous'] = 'None'
vim.vars['tracks'] = vim.Dictionary(results)
EOL
    let s:cache.track_search[a:track] = g:tracks
    endif
    let tracks = s:cache.track_search[a:track]
    if len(tracks['tracks']['items']) == 0
        echo "No tracks could be found"
        return
    endif
    call s:OpenWindow()
    0,$d
    call s:PrintTracks(tracks['tracks'])
    setlocal nomodifiable
    2
    call s:BufferTrackSearchMappings()
    call s:LoadSyntaxHightlighting()
endfunction

function! TrackFollow(line_number, column) dict
    " title line
    if a:line_number == 0
        return
    endif
    let track = self.tracks[a:line_number - 2]
    if a:column > 88
        call s:AlbumLookup(track.album.uri)
    elseif a:column > 54 && a:column < 89
        echo track
        call ArtistLookup(track.artists[0].uri)
    else
        call s:SpotifyOpenTrackUri(track.uri)
    endif
endfunction

function! MakeTrackFollower(tracks)
    let closure = { 'tracks': a:tracks }
    let closure.follow = function("TrackFollow")
    return closure
endfunction

function! s:PrintTracks(tracks)
    let shown_tracks = []
    call setline(1, printf("%-53S %-33S %5S", "Track", "Artist", "Album"))
    for track in a:tracks['items']
        " if s:AvailableInTerritory(track.territories)
        call add(shown_tracks, track)
        call append("$", printf("%-50.50S    %-30.30S    %S", track.name, track.artists[0].name, track.album.name))
        " endif
    endfor
    let b:FollowDict = MakeTrackFollower(shown_tracks)
    call s:AddTrailingWhiteSpace(1, line("$"))
endfunction

function! s:AvailableInTerritory(territories)
   let country_code = s:GetCountryCode()
   return country_code == "ANY" ||
               \  len(a:territories) == 0 ||
               \  index(a:territories, country_code) >= 0
endfunction

function! ArtistLookup(artist_uri)
    if ! has_key(s:cache.artist, a:artist_uri)
        python << EOL
import spotipy
import vim
s = spotipy.Spotify()
results = s.artist_albums(vim.eval("a:artist_uri"), album_type='album')
results['previous'] = 'None'
results['next'] = 'None'
vim.vars['tracks'] = vim.Dictionary(results)
EOL
        let s:cache.artist[a:artist_uri] = g:tracks
    endif
    let artist = s:cache.artist[a:artist_uri]
    call s:OpenWindow()
    0,$d
    call s:PrintArtistAlbums(artist)
    setlocal nomodifiable
    2
    call s:LoadSyntaxHightlighting()
endfunction

function! s:PrintArtistAlbums(artist)
    " call setline(1, printf("%S", a:artist['items'][0]))
    let shown_albums = []
    for album in a:artist.items
        " if s:AvailableInTerritory(album.territories)
        call add(shown_albums, album)
        call append("$", printf("%S", album.name))
        " endif
    endfor
    let b:FollowDict = s:MakeArtistFollower(shown_albums)
    call s:AddTrailingWhiteSpace(1, line("$"))
endfunction

function! ArtistFollow(line_number, column) dict
    " title line
    if a:line_number == 0
        return
    endif
    call s:AlbumLookup(self.albums[a:line_number - 2].uri)
endfunction

function! s:MakeArtistFollower(albums)
    let closure = { 'albums': a:albums }
    let closure.follow = function("ArtistFollow")
    return closure
endfunction

function! s:AlbumLookup(album_uri)
    let l:album = {}
    if ! has_key(s:cache.album, a:album_uri)
        python << EOL
import spotipy
import vim
s = spotipy.Spotify()
results = s.album(vim.eval("a:album_uri"))
results['tracks']['next'] = 'None'
results['tracks']['previous'] = 'None'
vim.vars['tracks'] = vim.Dictionary(results)
EOL
        let s:cache.album[a:album_uri] = g:tracks
    endif

    call s:OpenWindow()
    0,$d
    call s:PrintAlbum(s:cache.album[a:album_uri])
    setlocal nomodifiable
    keepjumps 2
    normal m'
    call s:BufferTrackSearchMappings()
    call s:LoadSyntaxHightlighting()
endfunction

function! AlbumFollow(line_number, column) dict
    " title line
    if a:line_number == 0
        return
    endif
    let track = self.album.tracks.items[a:line_number - 2]
    if a:column > 60
        call ArtistLookup(track.artists[0].uri)
    else
        call s:SpotifyOpenTrackUri(track.uri, self.album.uri)
    endif
endfunction

function! s:MakeAlbumFollower(album)
    let closure = { 'album': a:album }
    let closure.follow = function("AlbumFollow")
    return closure
endfunction

function! s:PrintAlbum(album)
    call setline(1, printf("%S - %S", a:album.name, a:album.artists[0].name))
    for track in a:album.tracks.items
        call append("$", printf("%-60.60S %S", track.name, track.artists[0].name))
    endfor
    let b:FollowDict = s:MakeAlbumFollower(a:album)
    call s:AddTrailingWhiteSpace(1, line("$"))
endfunction

" Add trailing whitespace for line alternate line highlighting
function! s:AddTrailingWhiteSpace(start, finish)
    let i = a:start
    while i <= a:finish
        if i % 2 == 0
            call setline(i, getline(i) . ' ')
        else
            call setline(i, getline(i) . '  ')
        endif
        let i = i + 1
    endwhile
endfunction

function! s:SpotifyClearCache()
    let s:cache = {"album": {}, "artist": {}, "track": {}, "track_search": {}}
endfunction

call s:SpotifyClearCache()

let s:SpotifyOpenTrackUri = function( s:GetOS() . "UriOpener")

command! -nargs=* Spotify call SpotifyTrackSearch("<args>")
command! -nargs=* S call SpotifyTrackSearch("<args>")
" command! -nargs=0 SpotifyClearCache call SpotifyClearCache()
