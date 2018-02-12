using BinDeps

@BinDeps.setup

somoclu_version="1.7.4"

link = "https://github.com/peterwittek/somoclu/releases/download/$somoclu_version/somoclu-$(somoclu_version).tar.gz"

println(link)

if !is_windows()
	libjlsomoclu = library_dependency("libjlsomoclu",
								 aliases=["libjlsomoclu", "libjlsomoclu.so"], os=:Unix)
	provides(Sources, Dict([URI(link) => libjlsomoclu]))
	provides(BuildProcess,
			Autotools(libtarget = joinpath("src", "libjlsomoclu.so"),
			configure_options=[AbstractString("--without-mpi")]), libjlsomoclu, os=:Unix)
	@BinDeps.install Dict([:libjlsomoclu => :libjlsomoclu])
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

	libjlsomoclu = library_dependency("libjlsomoclu",
								 aliases=["libjlsomoclu", "libjlsomoclu.dll"],
								 os=:Windows)
	provides(Sources, Dict([URI(link) => libjlsomoclu]))


	makedeplnk = "https://sourceforge.net/projects/gnuwin32/files/make/3.81/make-3.81-dep.zip/download"
	makebinlnk = "https://sourceforge.net/projects/gnuwin32/files/make/3.81/make-3.81-bin.zip/download"

	makedepzip 	= joinpath(BinDeps.downloadsdir(libjlsomoclu), "make-3.81-dep.zip")
	makebinzip   = joinpath(BinDeps.downloadsdir(libjlsomoclu), "make-3.81-bin.zip")
	makebuilddir = joinpath(BinDeps.builddir(libjlsomoclu),  "make")

	make_s, make_d =
		joinpath(makebuilddir, "bin", "make.exe"),
		joinpath(BinDeps.bindir(libjlsomoclu), "make.exe")
	icnv_s, icnv_d =
		joinpath(makebuilddir, "bin", "libiconv2.dll"),
		joinpath(BinDeps.bindir(libjlsomoclu), "libiconv2.dll")
	intl_s, intl_d =
		joinpath(makebuilddir, "bin", "libintl3.dll"),
		joinpath(BinDeps.bindir(libjlsomoclu), "libintl3.dll")

	somoclusrcdir   = joinpath(BinDeps.srcdir(libjlsomoclu),   "somoclu-$somoclu_version")
	somoclubuilddir = joinpath(BinDeps.builddir(libjlsomoclu), "somoclu-$somoclu_version")
	somoclumakefile = joinpath(BinDeps.depsdir(libjlsomoclu),  "Makefile.libsomoclu.mingw")

	provides(SimpleBuild,
		(@build_steps begin
			CreateDirectory(BinDeps.bindir(libjlsomoclu))
			FileRule(joinpath(BinDeps.bindir(libjlsomoclu), "make.exe"), @build_steps begin
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
			GetSources(libjlsomoclu)
			CreateDirectory(somoclubuilddir)
			@build_steps begin
				ChangeDirectory(somoclubuilddir)
				FileRule("Makefile", ()-> begin
					println("Copying... Makefile")
					cp(somoclumakefile, joinpath(somoclubuilddir, "Makefile"),
					   remove_destination=true)
					end)
				`../../usr/bin/make.exe ARCH=$(Sys.ARCH) version=$(somoclu_version)`
				CreateDirectory(BinDeps.libdir(libjlsomoclu))
				FileRule(joinpath(BinDeps.usrdir(libjlsomoclu),"lib","libjlsomoclu.dll"), ()->
					cp("libjlsomoclu.dll", joinpath(BinDeps.libdir(libjlsomoclu), "libjlsomoclu.dll"),
					   remove_destination=true))
			end
		end), libjlsomoclu, os=:Windows)

    push!(BinDeps.defaults, SimpleBuild)
	@BinDeps.install Dict([:libjlsomoclu => :libjlsomoclu])
    pop!(BinDeps.defaults)
end
