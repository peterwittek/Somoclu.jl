using BinDeps

@BinDeps.setup

link = "https://github.com/peterwittek/somoclu/releases/download/1.6.2/somoclu-1.7.0-pre.tar.gz"

libsomoclu = library_dependency("libsomoclu")

provides(Sources, Dict(URI(link) => libsomoclu))

provides(BuildProcess, Autotools(libtarget = joinpath("src", "libsomoclu.so"), configure_options=[AbstractString("--without-mpi")]), libsomoclu)

@BinDeps.install Dict(:libsomoclu => :libsomoclu)
