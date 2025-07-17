curlVersion=$(curl -V | head -1 | cut -d' ' -f2)

# Curl flags to handle redirects, not use EPSV, handle cookies for
# servers to need them during redirects, and work on SSL without a
# certificate (this isn't a security problem because we check the
# cryptographic hash of the output anyway).
curl=(
    curl
    --location
    --max-redirs 20
    --retry 3
    --retry-all-errors
    --continue-at -
    --disable-epsv
    --cookie-jar cookies
    --user-agent "curl/$curlVersion Nixpkgs/$nixpkgsVersion"
    --insecure
)

curlRetry() {
    local curlexit=18
    # if we get error code 18, resume partial download
    while [ $curlexit -eq 18 ]; do
        curlexit=0
        "${curl[@]}" --fail "$@" || curlexit=$?
    done
    return $curlexit
}

tryDownload() {
    local mirror="$1"
    local url="$mirror/$filename"
    echo
    echo "trying $url"
    local curlexit=18;

    curlRetry "$url.minisig$urlQuery" --output "$TMPDIR/$filename.minisig" || return
    curlRetry "$url$urlQuery" --output "$out" || return

    # check signature
    if ! minisign -Vm "$out" -x "$TMPDIR/$filename.minisig" -P "$minisignPublicKey"; then
        echo "minisign verification failed!!"
        return 111
    fi

    return 0
}

echo "loading mirrors from $mirrorFile"
shuf  <"$mirrorFile" | while read -r mirror; do
    tryDownload "$mirror" && break
done
