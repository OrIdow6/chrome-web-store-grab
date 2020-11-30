#!/usr/bin/python3
# You do not need to run this file when running the script! Generation of platforms.txt all_platforms.txt is already done for you!

import sys

def makeParams(os, nacl_arch, prodversion=100):
	assert nacl_arch in {"x86-64","x86-32","arm","arm64","mips32","mips64","ppc64"}
	arch = {"x86-64": "x64", "x86-32": "x86", "arm": "arm", "arm64": "arm64", "mips64": "mips64el", "mips32": "mipsel", "ppc64": "ppc64"}[nacl_arch]
	os_arch = {"x86-64": "x86_64", "x86-32": "x86"}.get(nacl_arch, nacl_arch)
	prod = "chromecrx" # Determined to be this in WebstoreInstaller::GetWebstoreInstallURL's call to UpdateQueryParams::Get
	print("response=redirect&os={}&arch={}&os_arch={}&nacl_arch={}&prod={}&acceptformat=crx3&prodversion={}".format(
		os,
		arch,
		os_arch,
		nacl_arch,
		prod,
		prodversion
		))

makeParams("win", "x86-64")
makeParams("cros", "x86-64")
makeParams("cros", "arm64")
makeParams("win", "x86-32")
makeParams("mac", "x86-64")
makeParams("mac", "x86-32")
makeParams("linux", "x86-64")
makeParams("linux", "x86-32")

if len(sys.argv) > 1:
	for i in range(1, 100, 5):
		# I suspect that a small minority of extensions will trigger this
		# However, if I'm wrong, only go every 5 versions, not all 1000 possible versions
		makeParams("win", "x86-64", str(i))
		makeParams("cros", "x86-64", str(i))
		makeParams("cros", "arm64", str(i))
		makeParams("win", "x86-32", str(i))
		makeParams("mac", "x86-64", str(i))
		makeParams("mac", "x86-32", str(i))
		makeParams("linux", "x86-64", str(i))
		makeParams("linux", "x86-32", str(i))
