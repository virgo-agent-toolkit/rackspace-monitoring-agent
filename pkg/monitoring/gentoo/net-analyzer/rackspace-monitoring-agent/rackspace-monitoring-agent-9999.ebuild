# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=4

inherit git-2

DESCRIPTION="Rackspace monitoring agent"
HOMEPAGE="https://www.rackspace.com/"

EGIT_REPO_URI="https://github.com/racker/virgo.git"
EGIT_BRANCH="gentoo"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND="dev-vcs/git"
RDEPEND="${DEPEND}"

pkg_setup() {
	git submodule update --init --recursive
}

src_configure() {
	./configure || die "failed configure"
}

src_compile() {
	make || die "failed make"
}

src_install() {
	make install DESTDIR="${D}" || die "failed install"

	dodir /etc/init.d
	cp "${FILESDIR}"/init "${D}"/etc/init.d/rackspace-monitoring-agent
}
