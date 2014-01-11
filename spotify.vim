let s:spotify_track_search_url = "http://ws.spotify.com/search/1/track.json?q="

function! s:OpenUri(uri)
    " exec "silent !explorer " . a:uri
    exec "silent !spotify " . a:uri
endfunction

function! PlayTrack()
    let uri = b:uris[line(".")-2]
    silent call s:OpenUri(uri)
endfunction

function! s:CurlIntoBuffer(url)
    " exec 'silent r!curl -s "' . a:url . '"'
    exec 'silent r!wget -qO- "' . a:url . '"'
endfunction

function! s:SearchSpot(track)
    call s:CurlIntoBuffer(s:spotify_track_search_url . a:track)
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
    nnoremap <buffer> <CR> :silent call PlayTrack()<CR>
    nnoremap <buffer> <2-LeftMouse> :call PlayTrack()<CR>
    nnoremap <buffer> q <C-W>q
endfunction

function! SearchTrack(track)
    call s:OpenWindow()
    0,$d
    let cleantrack = substitute(a:track, " ", "\\\\%20", "g")
    echo "Downloading Search now"
    call s:SearchSpot(cleantrack)
    silent 1d
    call s:TrackParse()
    setlocal nomodifiable
    2
endfunction

function! s:TrackParse()
    silent s/{"album"/\r&/g
    silent 1d
    call append(0, "Track    Artist    Release Year    Album")
    silent! 2,$s/\\"//g
    silent! 2,$s/\v.*\{"released": "(\d{4})", "href": "[^"]+", "name": "([^"]+)", "availability": \{"territories": "[^"]+"\}}, "name": "([^"]+)", .*"popularity": .*"(spotify:track:[^"]+)", "artists": .*name": "([^"]+)"}].*/\3    \5    \1    \2\4
    let b:uris = []
    let i = 2
    let last = line("$")
    while i < last
        call add(b:uris, getline(i)[-36:])
        let i = i + 1
    endwhile
    silent! 2,$s/.\{36}$//
    if exists(":Tabularize")
        silent! %Tabularize /    
    endif
    silent! %s;\\;;g
endfunction

command! -nargs=* SpotifySearch call SearchTrack("<args>")
