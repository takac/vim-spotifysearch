" Author: Tom Cammann 
" Version: 0.2

if &cp || version < 700
    finish
end

let s:spotify_track_search_url = "http://ws.spotify.com/search/1/track.json?q="

function! s:OpenUri(uri)
    if has("win32")
        call system("explorer " . a:uri)
    elseif has("unix")
        call system("spotify " . a:uri)
    else
        " TODO others
        throw "Platform unsupported"
    endif
endfunction

function! PlayTrack()
    let uri = b:uris[line(".")-2]
    silent call s:OpenUri(uri)
endfunction

function! s:CurlIntoBuffer(url)
    exec 'silent r!curl -s "' . a:url . '"'
endfunction

function! s:WgetIntoBuffer(url)
    exec 'silent r!wget -qO- "' . a:url . '"'
endfunction

function! s:SearchSpotIntoBuffer(track)
    let l:trackUri = s:spotify_track_search_url . a:track
    if executable("curl")
        call s:CurlIntoBuffer(l:trackUri)
    elseif executable("wget")
        call s:WgetIntoBuffer(l:trackUri)
    elseif exists(":Nread")
        throw "No supported yet.."
        " Use netrw to read from network
        let l:command = 'silent! edit! '. l:trackUri
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
    " mappings
    nnoremap <buffer> <CR> :silent call PlayTrack()<CR>
    nnoremap <buffer> <2-LeftMouse> :call PlayTrack()<CR>
    nnoremap <buffer> q <C-W>q
    " highlighting
    syn match trackOne '.*\S\s$' display
    syn match trackTwo '.*\s\s$' display
    syn match headers 'Track\s*Artist\s*Release Year\s*Album'
    hi def link trackOne Type
    hi def link trackTwo PreProc
    hi def link headers Comment
endfunction

function! SearchTrack(track)
    call s:OpenWindow()
    0,$d
    let cleantrack = substitute(a:track, " ", "\\\\%20", "g")
    echo "Downloading Search now"
    call s:SearchSpotIntoBuffer(cleantrack)
    silent 1d
    call s:TrackParse()
    setlocal nomodifiable
    2
endfunction

function! s:TrackParse()
    silent s/{"album"/\r&/g
    silent 1d
    call append(0, printf("%-53s %-33s %s %6s", "Track", "Artist", "Release Year", "Album"))
    silent! 2,$s/\\"//g
    " Convert unicode characters
    silent! 2,$s#\\u[0-9a-f]\{0,6}#\=eval('"'.submatch(0).'"')#g
    " Format json to track list!
    silent! 2,$s/\v.*\{"released": "(\d{4})", "href": "[^"]+", "name": "([^"]+)", "availability": \{"territories": "[^"]+"\}}, "name": "([^"]*)", .*"popularity": .*"(spotify:track:[^"]+)", "artists": .*name": "([^"]+)"}].*/\=printf("%-50.50s    %-30.30s    %-10s    %s%s", submatch(3), submatch(5), submatch(1), submatch(2), submatch(4))/
    let b:uris = []
    let i = 2
    let last = line("$")
    while i <= last
        call add(b:uris, getline(i)[-36:])
        call setline(i, getline(i)[:-37])
        let i = i + 1
    endwhile
    let i = 2
    " Add trailing whitespace for line alternate line highlighting
    while i <= last
        if i % 2 == 0
            call setline(i, getline(i) . ' ')
        else 
            call setline(i, getline(i) . '  ')
        endif
        let i = i + 1
    endwhile
endfunction

command! -nargs=* SpotifySearch call SearchTrack("<args>")
