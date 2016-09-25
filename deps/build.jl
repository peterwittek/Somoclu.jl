using BinDeps

@BinDeps.setup

commit = "d01efaa5de2cb54c0d378c8f077d641b0d4dd843"
repo = "https://github.com/peterwittek/somoclu/archive/$commit.zip"
somocluname = "somoclu-$commit"

libsomoclu = library_dependency("libsomoclu")

provides(Sources, Dict(URI(repo) => libsomoclu), unpacked_dir="$somocluname")

provides(BuildProcess, Autotools(libtarget = joinpath("src", "libsomoclu.so"), configure_options=[AbstractString("--without-mpi")]), libsomoclu)

@BinDeps.install Dict(:libsomoclu => :libsomoclu)
