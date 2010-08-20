<?xml version="1.0" encoding="ISO-8859-1"?>
<!--
 Copyright (c) 2008-2010 Hewlett-Packard Development Company, L.P.
 All Rights Reserved.
-->

<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

	<xsl:output method="text"/>

	<!-- Suppress built-in processing of all text nodes. -->
	<xsl:template match="text()"/>

	<!-- Build the path to this element from the parent down excluding the root target element -->
	<xsl:template match="entry" mode="path">
		<xsl:for-each select="ancestor::entry[@path]">
			<xsl:value-of select="@path"/>
			<xsl:text>/</xsl:text>
		</xsl:for-each>
		<xsl:value-of select="@path"/>
	</xsl:template>

	<!-- From: http://svn.haxx.se/dev/archive-2005-08/0103.shtml
		added		*
		conflicted	*
		deleted		*
		ignored		*
		modified	
		replaced	
		external	
		unversioned	*
		incomplete	*
		obstructed	*
		normal		
		none
	-->
	<xsl:template match="//wc-status[@item = 'added' or @item = 'conflicted' or @item='deleted' or @item = 'ignored' or @item='unversioned' or @item='incomplete' or @item='obstructed']">
		<xsl:apply-templates select=".." mode="path"/>
		<xsl:text>&#10;</xsl:text>
	</xsl:template>
</xsl:stylesheet>
