" Author: Tom Cammann
" Version: 0.4

if &cp || version < 700
    finish
end

let s:spotify_track_search_url = "http://ws.spotify.com/search/1/track.json?q="
let s:spotify_album_lookup_url = "http://ws.spotify.com/lookup/1/.json?extras=track&uri="
let s:spotify_artist_lookup_url = "http://ws.spotify.com/lookup/1/.json?extras=album&uri="

function! SpotifyOpenUri(uri)
    if has("win32") || has("win32unix")
        call system("explorer " . a:uri)
    elseif has("unix")
        let os = system("uname -s")
        if has("mac") || has("macunix") ||  os =~ "Darwin" || os =~ "Mac"
            call system("osascript -e 'tell application \"Spotify\"' -e 'play track \"" . a:uri . "\"' -e 'end tell'")
            if v:shell_error
                call system("open " . a:uri)
                if v:shell_error
                    throw "Could not open spotify uri, error no " . v:shell_error
                endif
            endif
        else
            call system("spotify " . a:uri)
            if v:shell_error
                throw "Could not open spotify, error no " . v:shell_error
            endif
        endif
    else
        " TODO others
        throw "Platform unsupported"
    endif
endfunction

function! PlayTrackMapping()
    call s:FollowDict.follow(line("."), virtcol("."))
endfunction

function! s:Curl(url)
    return system('curl -s "' . a:url . '"')
endfunction

function! s:GetUrl(url)
    if executable("curl")
        return s:Curl(a:url)
    elseif executable("wget")
        return s:Wget(a:url)
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
    setlocal buftype=nofile nobuflisted noswapfile nowrap modifiable
endfunction

" Mappings
function! s:BufferTrackSearchMappings()
    nnoremap <silent> <buffer> <CR> :silent call PlayTrackMapping()<CR>
    nnoremap <silent> <buffer> <2-LeftMouse> :call PlayTrackMapping()<CR>
    nnoremap <silent> <buffer> q <C-W>q
    exec 'nnoremap <silent> <buffer> s :call SpotifyOpenUri("spotify:search:' . s:search_term . '")<CR>'
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

function! SpotifyTrackSearch(track)
    if len(a:track) == 0
        call s:OpenWindow()
        return
    endif
    let b:isArtist = 0
    let b:isAlbum = 0
    if has_key(s:cache.track_search, a:track)
        let tracks = s:cache.track_search[a:track]
    else
        let s:search_term = substitute(a:track, " ", "+", "g")
        let cleantrack = substitute(a:track, " ", "\\\\%20", "g")
        echo "Downloading Search now"
        let l:url = s:spotify_track_search_url . l:cleantrack
        let tracks = s:TrackSearchParse(s:GetUrl(l:url))
        let s:cache.track_search[a:track] = tracks
    endif
    if len(tracks) == 0
        echo "No tracks could be found"
        return
    endif
    call s:OpenWindow()
    0,$d
    call s:PrintTracks(tracks)
    setlocal nomodifiable
    2
    call s:BufferTrackSearchMappings()
    call s:LoadSyntaxHightlighting()
endfunction

function! s:CleanString(string)
    " remove escaped quotes
    let clean = substitute(a:string, '\\"', '"', 'g')
    let clean = substitute(a:string, '\\/', '/', 'g')
    " Convert unicode characters
    return substitute(clean, '\\u[0-9a-f]\{2,6}', "\\=eval('\"'.submatch(0).'\"')", 'g')
endfunction

function! s:TrackSearchParse(json)
    let splitter = split(a:json, '{"album"\zs')[1:]
    let track_list = []
    for item in splitter
        let item = s:CleanString(item)
        let contents = matchlist(item, '\v.*\{"released": "(\d{4})", "href": "([^"]+)", "name": "([^"]+)", "availability": \{"territories": "([^"]*)"\}\}, "name": "([^"]*)", .*"popularity": .*"(spotify:track:[^"]+)", "artists": .+"href": "([^"]*)".+ "name": "([^"]+)"}].*')
        let track = {
                    \ "year": contents[1],
                    \ "album": { "uri": contents[2], "name": contents[3] },
                    \ "territories": split(contents[4]),
                    \ "name": contents[5],
                    \ "uri": contents[6],
                    \ "artist": { "uri": contents[7], "name": contents[8] }
                    \ }
        call add(track_list, track)
    endfor
    return track_list
endfunction

function! TrackFollow(line_number, column) dict
    " title line
    if a:line_number == 0
        return
    endif
    let track = self.tracks[a:line_number - 2]
    if a:column > 102
        call s:AlbumLookup(track.album.uri)
    elseif a:column > 54 && a:column < 89
        call ArtistLookup(track.artist.uri)
    else
        call SpotifyOpenUri(track.uri)
    endif
endfunction

function! MakeTrackFollower(tracks)
    let closure = { 'tracks': a:tracks }
    let closure.follow = function("TrackFollow")
    return closure
endfunction

function! s:PrintTracks(tracks)
    let shown_tracks = []
    call setline(1, printf("%-53s %-33s %s %6s", "Track", "Artist", "Release Year", "Album"))
    for track in a:tracks
        if s:AvailableInTerritory(track.territories)
            call add(shown_tracks, track)
            call append("$", printf("%-50.50S    %-30.30S    %-10S    %S", track.name, track.artist.name, track.year, track.album.name))
        endif
    endfor
    let s:FollowDict = MakeTrackFollower(shown_tracks)
    call s:AddTrailingWhiteSpace(1, line("$"))
endfunction

function! s:AvailableInTerritory(territories)
   return len(a:territories) == 0 || index(a:territories, "GB") >= 0
endfunction

function! ArtistLookup(albumUri)
    echo "Downloading Search now"
    let l:url = s:spotify_artist_lookup_url . a:albumUri
    let artist = s:ArtistParse(s:GetUrl(l:url))
    call s:OpenWindow()
    0,$d
    call s:PrintArtist(artist)
    setlocal nomodifiable
    2
    call s:LoadSyntaxHightlighting()
endfunction

function! s:ArtistParse(json)
    let split_albums = split(a:json, '{"album"\zs')
    " Extract Artist Name from last line
    let name = matchlist(s:CleanString(split_albums[-1]), '\v.* "name": "([^"]*)".*')[1]
    let albums = []
    for item in split_albums[1:]
        let item = s:CleanString(item)
        let contents = matchlist(item, '\v.*"name": "([^"]+)".* "href": "(spotify:album:[^"]+)", "availability": \{"territories": "([^"]*)"\}', 0, 1)[0:3]
        " Sometimes href and name are in the other order...
        if len(contents) != 4
            let matched = matchlist(item, '\v.*"href": "(spotify:album:[^"]*)", "availability": \{"territories": "([^"]*)"\}, "name": "([^"]*)".* ')[0:3]
            let contents = [matched[0], matched[3], matched[1], matched[2]]
        endif
        let album = { 'name' : contents[1], 'uri': contents[2], 'territories': split(contents[3]) }
        call add(albums, album)
    endfor
    return { "albums": albums, "name": name }
endfunction

function! s:PrintArtist(artist)
    call setline(1, printf("%S", a:artist.name))
    let shown_albums = []
    for album in a:artist.albums
        if s:AvailableInTerritory(album.territories)
            call add(shown_albums, album)
            call append("$", printf("%S", album.name))
        endif
    endfor
    let s:FollowDict = s:MakeArtistFollower(shown_albums)
    call s:AddTrailingWhiteSpace(1, line("$"))
endfunction

function! ArtistFollow(line_number, column) dict
    " title line
    if a:line_number == 0
        return
    endif
    call s:AlbumLookup(self.albums[a:line_number - 1].uri)
endfunction

function! s:MakeArtistFollower(albums)
    let closure = { 'albums': a:albums }
    let closure.follow = function("ArtistFollow")
    return closure
endfunction

function! s:AlbumLookup(albumUri)
    echo "Downloading Search now"
    let l:album = {}
    if ! has_key(s:cache.album, a:albumUri)
        let l:url = s:spotify_album_lookup_url . a:albumUri
        let s:cache.album[a:albumUri] = s:AlbumParse(s:GetUrl(l:url))
    endif

    call s:OpenWindow()
    0,$d
    call s:PrintAlbum(s:cache.album[a:albumUri])
    setlocal nomodifiable
    2
    call s:LoadSyntaxHightlighting()
endfunction

function! AlbumFollow(line_number, column) dict
    " title line
    if a:line_number == 0
        return
    endif
    let track = self.album.tracks[a:line_number - 2]
    if a:column > 60
        call ArtistLookup(track.artist.uri)
    else
        call SpotifyOpenUri(track.uri)
    endif
endfunction

function! s:MakeAlbumFollower(album)
    let closure = { 'album': a:album }
    let closure.follow = function("AlbumFollow")
    return closure
endfunction

function! s:AlbumParse(json)
    let split_tracks = split(a:json, '{"available"\zs')
    "1: name, 2: artist, 3: year
    let info = matchlist(s:CleanString(split_tracks[0]), '\v.*"name": "([^"]*)".* "artist": "([^"]*)".* "released": "(\d{4})".*')
    let album_uri = matchlist(split_tracks[-1], '\v"href": "(spotify:album:.{22})"')[1]
    let album = {}
    let tracks = []
    for item in split_tracks[1:]
        let item = s:CleanString(item)
        let contents = matchlist(item, '\v.* "href": "([^"]{36})".* "artists": \[.+"href": "([^"]*)".+ "name": "([^"]*).*\].* "name": "([^"]+)".*"')
        let track = {
                    \ "uri": contents[1],
                    \ "artist": { "uri": contents[2], "name": contents[3] },
                    \ "name": contents[4]
                    \ }
        call add(tracks, track)
    endfor
    return { "tracks": tracks, "name": info[1], "year": info[3], "artist": { "name": info[2] }, "uri": album_uri }
endfunction

function! s:PrintAlbum(album)
    call setline(1, printf("%S - %S %S", a:album.name, a:album.artist.name, a:album.year))
    for track in a:album.tracks
        call append("$", printf("%-60.60s %s", track.name, track.artist.name))
    endfor
    let s:FollowDict = s:MakeAlbumFollower(a:album)
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

command! -nargs=* SpotifySearch call SpotifyTrackSearch("<args>")
command! -nargs=1 SpotifyOpenUri call SpotifyOpenUri("<args>")
command! -nargs=0 SpotifyClearCache call SpotifyClearCache()
