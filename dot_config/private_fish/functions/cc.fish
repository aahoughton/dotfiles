function cc
    set root (git rev-parse --show-toplevel 2>/dev/null; or echo $PWD)
    cd $root
    claude $argv
    cd -
end
