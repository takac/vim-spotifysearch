" Author: Tom Cammann
" Version: 0.3

if &cp || version < 700
    finish
end

let s:spotify_track_search_url = "http://ws.spotify.com/search/1/track.json?q="
let s:spotify_album_lookup_url = "http://ws.spotify.com/lookup/1/.json?extras=track&uri="
let s:spotify_artist_lookup_url = "http://ws.spotify.com/lookup/1/.json?extras=album&uri="

function! OpenSpotifyUri(uri)
    if has("win32") || has("win32unix")
        call system("explorer " . a:uri)
    elseif has("mac") || has("macunix")
        call system("osascript -e 'tell application \"Spotify\"' -e 'play track \"" . a:uri . "\"' -e 'end tell'")
        if v:shell_error
            call system("open " . a:uri)
            if v:shell_error
                throw "Could not open spotify uri, error no " . v:shell_error
            endif
        endif
    elseif has("unix")
        call system("spotify " . a:uri)
        if v:shell_error
            throw "Could not open spotify, error no " . v:shell_error
        endif
    else
        " TODO others
        throw "Platform unsupported"
    endif
endfunction

function! PlayTrackMapping()
    " Not on title line
    if line(".") == 1
        return
    endif
    let col = virtcol(".")
    let ln = line(".") - 2

    if b:isArtist
        call s:AlbumLookup(b:albumUris[ln])
    elseif b:isAlbum
        if col > 60
            call ArtistLookup(b:artistUris[ln])
        else
            call OpenSpotifyUri(b:trackUris[ln])
        endif
    else
        " isTrack..
        if col > 102
            call s:AlbumLookup(b:albumUris[ln])
        elseif col > 54 && col < 89
            call ArtistLookup(b:artistUris[ln])
        else
            call OpenSpotifyUri(b:trackUris[ln])
        endif
    endif
endfunction

function! s:CurlIntoBuffer(url)
    exec 'silent r!curl -s "' . a:url . '"'
endfunction

function! s:WgetIntoBuffer(url)
    exec 'silent r!wget -qO- "' . a:url . '"'
endfunction

function! s:UrlIntoBuffer(url)
    if executable("curl")
        call s:CurlIntoBuffer(a:url)
    elseif executable("wget")
        call s:WgetIntoBuffer(a:url)
    elseif exists(":Nread")
        throw "No supported yet.."
        " Use netrw to read from network
        let l:command = 'silent! edit! '. a:url
        exec l:command
    else
        throw "No viable method for calling json api"
    endif
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
function! s:BufferTrackMappings()
    nnoremap <silent> <buffer> <CR> :silent call PlayTrackMapping()<CR>
    nnoremap <silent> <buffer> <2-LeftMouse> :call PlayTrackMapping()<CR>
    nnoremap <silent> <buffer> q <C-W>q
    exec 'nnoremap <silent> <buffer> s :call OpenSpotifyUri("spotify:search:' . s:search_term . '")<CR>'
endfunction

" Highlighting
function! s:LoadSyntaxHightlighting()
    syn match trackOne '.*\S\s$' display
    syn match trackTwo '.*\s\s$' display
    syn match headers 'Track\s*Artist\s*Release Year\s*Album'
    hi def link trackOne Type
    hi def link trackTwo PreProc
    hi def link headers Comment
endfunction

function! TrackSearch(track)
    call s:OpenWindow()
    let b:isArtist = 0
    let b:isAlbum = 0
    0,$d
    let s:search_term = substitute(a:track, " ", "+", "g")
    let cleantrack = substitute(a:track, " ", "\\\\%20", "g")
    echo "Downloading Search now"
    let l:url = s:spotify_track_search_url . l:cleantrack
    call s:UrlIntoBuffer(l:url)
    silent 1d
    call s:TrackParse()
    setlocal nomodifiable
    2
    call s:BufferTrackMappings()
    call s:LoadSyntaxHightlighting()
endfunction

function! ArtistLookup(albumUri)
    call s:OpenWindow()
    let b:isArtist = 1
    let b:isAlbum = 0
    0,$d
    echo "Downloading Search now"
    let l:url = s:spotify_artist_lookup_url . a:albumUri
    call s:UrlIntoBuffer(l:url)
    silent 1d
    call s:ArtistParse()
    setlocal nomodifiable
    2
    call s:BufferTrackMappings()
    call s:LoadSyntaxHightlighting()
endfunction

function! s:ArtistParse()
    silent! s/\ze{"album":/\r/g
    silent! %s/\\"//g
    silent! %s#\\u[0-9a-f]\{2,6}#\=eval('"'.submatch(0).'"')#g
    " Extract Artist Name
    silent! $s/\v(.*) "name": "([^"]*)".*/\1\r\2 - Albums
    " Parse Albums
    silent! 2,$s/\v.*"name": "([^"]*)".* "href": "(spotify:album:[^"]*)".*/\1\2
    " Sometimes href and name are in the other order...
    silent! 2,$s/\v.*"href": "(spotify:album:[^"]*)".* "name": "([^"]*)".* /\2\1

    silent! 1d
    silent! $m0
    let b:albumUris = []
    let i = 2
    let last = line("$")
    while i <= last
        let line = getline(i)
        call add(b:albumUris, line[-36:])
        call setline(i, line[:-37])
        let i = i + 1
    endwhile
endfunction

function! s:AlbumLookup(albumUri)
    call s:OpenWindow()
    let b:isArtist = 0
    let b:isAlbum = 1
    0,$d
    echo "Downloading Search now"
    let l:url = s:spotify_album_lookup_url . a:albumUri
    call s:UrlIntoBuffer(l:url)
    silent 1d
    call s:AlbumParse()
    setlocal nomodifiable
    2
    call s:LoadSyntaxHightlighting()
endfunction

function! s:AlbumParse()
    silent! s/\ze{"available"/\r/g
    silent! %s/\\"//g
    silent! %s#\\u[0-9a-f]\{2,6}#\=eval('"'.submatch(0).'"')#g
    silent! 1s/\v.*"name": "([^"]*)".* "artist": "([^"]*)".* "released": "(\d{4})".*/\1 - \2 - \3
    " groups - track uri, artist uri, artist name, track name
    silent! 2,$s/\v.* "href": "([^"]{36})".* "artists": \[.+"href": "([^"]*)".+ "name": "([^"]*).*\].* "name": "([^"]+)".*/\=printf("%-60.60s %s%s%s", submatch(4), submatch(3), submatch(2), submatch(1)) 
    $d
    let b:trackUris = []
    let b:artistUris = []
    let i = 2
    let last = line("$")
    while i <= last
        let line = getline(i)
        call add(b:trackUris, line[-36:])
        call add(b:artistUris, line[-73:-37])
        call setline(i, line[:-74])
        let i = i + 1
    endwhile
    call s:AddTrailingWhiteSpace(2, l:last)
endfunction

function! s:TrackParse()
    silent s/{"album"/\r&/g
    silent 1d
    silent! %s/\\"//g
    " Convert unicode characters
    silent! %s#\\u[0-9a-f]\{2,6}#\=eval('"'.submatch(0).'"')#g
    " Format json to track list!
    silent! %s/\v.*\{"released": "(\d{4})", "href": "([^"]+)", "name": "([^"]+)", "availability": \{"territories": "[^"]+"\}}, "name": "([^"]*)", .*"popularity": .*"(spotify:track:[^"]+)", "artists": .+"href": "([^"]*)".+ "name": "([^"]+)"}].*/\=printf("%-50.50S    %-30.30S    %-10S    %S%S%S%S", submatch(4), submatch(7), submatch(1), submatch(3), submatch(6), submatch(2), submatch(5))/
    let b:trackUris = []
    let b:albumUris = []
    let b:artistUris = []
    let i = 1
    let last = line("$")
    while i <= last
        let line = getline(i)
        call add(b:trackUris, line[-36:])
        call add(b:albumUris, line[-72:-37])
        call add(b:artistUris, line[-109:-73])
        call setline(i, line[:-110])
        let i = i + 1
    endwhile
    call s:AddTrailingWhiteSpace(1, l:last)
    call append(0, printf("%-53s %-33s %s %6s", "Track", "Artist", "Release Year", "Album"))
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
endfunctio

command! -nargs=* SpotifySearch call TrackSearch("<args>")
command! -nargs=1 SpotifyOpenUri call OpenSpotifyUri("<args>")
