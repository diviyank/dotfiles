function orgsync
    pushd ~/orgfiles
    git pull
    git add .
    git commit -m '[DEV] Update orgfiles'
    git push
    popd
end
