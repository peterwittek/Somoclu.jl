using BinDeps

@BinDeps.setup

somoclu_version="1.7.5"

link = "https://github.com/peterwittek/somoclu/releases/download/$(somoclu_version)/somoclu-$(somoclu_version).tar.gz"

if !is_windows()
	libsomoclu = library_dependency("libsomoclu",
								 aliases=["libsomoclu", "libsomoclu.so"], os=:Unix)
	provides(Sources, Dict([URI(link) => libsomoclu]))
	provides(BuildProcess,
			 Autotools(libtarget=joinpath("src", "libsomoclu.so"),
			           configure_options=[AbstractString("--without-mpi")]), libsomoclu, os=:Unix)
	@BinDeps.install Dict([:libsomoclu => :libsomoclu])
else
    using WinRPM
	using Base.Filesystem
	using Base.Libdl

	WinRPM.install("gcc", yes=true)
	WinRPM.install("binutils", yes=true)
	WinRPM.install("gcc-c++", yes=true)
	WinRPM.install("libstdc++6", yes=true)
	WinRPM.install("libwinpthread1", yes=true)
	WinRPM.install("win_iconv", yes=true)
	WinRPM.install("zlib1", yes=true)

	GCCROOT = joinpath(Pkg.dir("WinRPM"),"deps")

	libsomoclu = library_dependency("libsomoclu",
								 aliases=["libsomoclu", "libsomoclu.dll"],
								 os=:Windows)
	provides(Sources, Dict([URI(link) => libsomoclu]))


	makedeplnk = "https://sourceforge.net/projects/gnuwin32/files/make/3.81/make-3.81-dep.zip/download"
	makebinlnk = "https://sourceforge.net/projects/gnuwin32/files/make/3.81/make-3.81-bin.zip/download"

	makedepzip 	= joinpath(BinDeps.downloadsdir(libsomoclu), "make-3.81-dep.zip")
	makebinzip   = joinpath(BinDeps.downloadsdir(libsomoclu), "make-3.81-bin.zip")
	makebuilddir = joinpath(BinDeps.builddir(libsomoclu),  "make")

	make_s, make_d =
		joinpath(makebuilddir, "bin", "make.exe"),
		joinpath(BinDeps.bindir(libsomoclu), "make.exe")
	icnv_s, icnv_d =
		joinpath(makebuilddir, "bin", "libiconv2.dll"),
		joinpath(BinDeps.bindir(libsomoclu), "libiconv2.dll")
	intl_s, intl_d =
		joinpath(makebuilddir, "bin", "libintl3.dll"),
		joinpath(BinDeps.bindir(libsomoclu), "libintl3.dll")

	somoclusrcdir   = joinpath(BinDeps.srcdir(libsomoclu),   "somoclu-$somoclu_version")
	somoclubuilddir = joinpath(BinDeps.builddir(libsomoclu), "somoclu-$somoclu_version")
	somoclumakefile = joinpath(somoclusrcdir, "src", "Makefile.libsomoclu.mingw")

	provides(SimpleBuild,
		(@build_steps begin
			CreateDirectory(BinDeps.bindir(libsomoclu))
			FileRule(joinpath(BinDeps.bindir(libsomoclu), "make.exe"), @build_steps begin
				FileDownloader(makedeplnk, makedepzip)
				FileDownloader(makebinlnk, makebinzip)
				FileUnpacker(makedepzip, makebuilddir, joinpath("bin", "libiconv2.dll"))
				FileUnpacker(makebinzip, makebuilddir, joinpath("bin", "make.exe"))
				()-> begin
					cp(make_s, make_d, remove_destination=true)
					cp(icnv_s, icnv_d, remove_destination=true)
					cp(intl_s, intl_d, remove_destination=true)
				end
			end)
			GetSources(libsomoclu)
			CreateDirectory(somoclubuilddir)
			@build_steps begin
				ChangeDirectory(somoclubuilddir)
				FileRule("Makefile", ()-> begin
					println("Copying... Makefile")
					cp(somoclumakefile, joinpath(somoclubuilddir, "Makefile"),
					   remove_destination=true)
					end)
				`../../usr/bin/make.exe ARCH=$(Sys.ARCH) version=$(somoclu_version)`
				CreateDirectory(BinDeps.libdir(libsomoclu))
				FileRule(joinpath(BinDeps.usrdir(libsomoclu),"lib","libsomoclu.dll"), ()->
					cp("libsomoclu.dll", joinpath(BinDeps.libdir(libsomoclu), "libsomoclu.dll"),
					   remove_destination=true))
			end
		end), libsomoclu, os=:Windows)

    push!(BinDeps.defaults, SimpleBuild)
	@BinDeps.install Dict([:libsomoclu => :libsomoclu])
    pop!(BinDeps.defaults)
end
