function orgsync
    pushd ~/orgfiles
    git pull --autostash
    git add .
    git commit -m '[DEV] Update orgfiles'
    git push
    popd
end
