include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-mosdns-panel
PKG_VERSION:=1.0.1
PKG_RELEASE:=1

PKG_MAINTAINER:=OpenWrt Community
PKG_LICENSE:=MIT

LUCI_TITLE:=MosDNS Panel for LuCI
LUCI_PKGARCH:=all
LUCI_DEPENDS:=+luci-app-mosdns +luci-base +curl

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
