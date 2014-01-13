" Author: Tom Cammann 
" Version: 0.2

if &cp || version < 700
    finish
end

let s:spotify_track_search_url = "http://ws.spotify.com/search/1/track.json?q="
let s:spotify_album_lookup_url = "http://ws.spotify.com/lookup/1/.json?extras=track&uri="

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

function! PlayTrackMapping()
    " Not on title line
    if line(".") == 1
        return
    endif
    let col = virtcol(".")

    " Open album
    if col > 102
        call OpenAlbum(b:albumUris[line(".")-2])
    else
        let uri = b:trackUris[line(".")-2]
        silent call s:OpenUri(uri)
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
        call s:LoadSyntaxHightlighting()
    endif
    setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap modifiable
endfunction

" Mappings
function! s:BufferTrackMappings()
    nnoremap <buffer> <CR> :silent call PlayTrackMapping()<CR>
    nnoremap <buffer> <2-LeftMouse> :call PlayTrackMapping()<CR>
    nnoremap <buffer> q <C-W>q
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

function! SearchTrack(track)
    call s:OpenWindow()
    call s:BufferTrackMappings()
    0,$d
    let cleantrack = substitute(a:track, " ", "\\\\%20", "g")
    echo "Downloading Search now"
    let l:url = s:spotify_track_search_url . l:cleantrack
    call s:UrlIntoBuffer(l:url)
    silent 1d
    call s:TrackParse()
    setlocal nomodifiable
    2
endfunction

function! OpenAlbum(albumUri)
    call s:OpenWindow()
    0,$d
    echo "Downloading Search now"
    let l:url = s:spotify_album_lookup_url . a:albumUri
    call s:UrlIntoBuffer(l:url)
    silent 1d
    call AlbumParse()
    setlocal nomodifiable
    2
endfunction

function! AlbumParse()
    silent! s/\ze{"available"/\r/g
    silent! %s/\\"//g
    silent! 1s/\v.*"name": "([^"]*)".* "artist": "([^"]*)".* "released": "(\d{4})".*/\1 - \2 - \3
    silent! 2,$s/\v.* "href": "([^"]*)".* "name": "([^"]*).*/\2\1
    let b:trackUris = []
    let i = 2
    let last = line("$")
    while i <= last
        let line = getline(i)
        call add(b:trackUris, line[-36:])
        call setline(i, line[:-37])
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
    silent! %s/\v.*\{"released": "(\d{4})", "href": "([^"]+)", "name": "([^"]+)", "availability": \{"territories": "[^"]+"\}}, "name": "([^"]*)", .*"popularity": .*"(spotify:track:[^"]+)", "artists": .*name": "([^"]+)"}].*/\=printf("%-50.50s    %-30.30s    %-10s    %s%s%s", submatch(4), submatch(6), submatch(1), submatch(3), submatch(2), submatch(5))/
    let b:trackUris = []
    let b:albumUris = []
    let i = 1
    let last = line("$")
    while i <= last
        let line = getline(i)
        call add(b:trackUris, line[-36:])
        call add(b:albumUris, line[-72:-37])
        call setline(i, line[:-73])
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
endfunction

command! -nargs=* SpotifySearch call SearchTrack("<args>")
