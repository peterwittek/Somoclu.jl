using BinDeps

@BinDeps.setup

link = "https://github.com/peterwittek/somoclu/releases/download/1.7.2/somoclu-1.7.2.tar.gz"
libsomoclu = library_dependency("libsomoclu", aliases=["libsomoclu", "libsomoclu.so"], os=:Unix)
provides(Sources, Dict(URI(link) => libsomoclu))
provides(BuildProcess, Autotools(libtarget = joinpath("src", "libsomoclu.so"), configure_options=[AbstractString("--without-mpi")]), libsomoclu, os = :Unix)
@BinDeps.install Dict(:libsomoclu => :libsomoclu)
