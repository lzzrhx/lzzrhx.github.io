<xsl:stylesheet
  version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:atom="http://www.w3.org/2005/Atom"
  exclude-result-prefixes="atom"
>
<xsl:output method="html" version="1.0" encoding="utf-8" indent="yes"/>
<xsl:strip-space elements="*"/>
  <xsl:template match="/">
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1"/>
        <title>feed.xml</title>
        <link rel="shortcut icon" href="/favicon.png" />
        <link rel="stylesheet" href="/main.css" type="text/css" />
      </head>
      <body>
        <main>
            <section class="posts">
            <b>XML feed:</b>
            <hr />
            <ul>
            <xsl:apply-templates select="atom:feed/atom:entry" />
            </ul>
            <hr />
            <li><small><a href="/">[ Go back ]</a></small><small><xsl:value-of select="atom:feed/atom:id"/></small></li>
          </section>
        </main>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="atom:entry">
    <li>
        <a><xsl:attribute name="href"><xsl:value-of select="atom:id"/></xsl:attribute><xsl:value-of select="atom:title"/></a>
        <xsl:variable name="date" select="substring-before(atom:updated, 'T')"/>
        <!-- day -->
        <xsl:value-of select="number(substring($date, 9, 2))"/>
        <xsl:text> </xsl:text>
        <!-- month -->
        <xsl:variable name="m" select="substring($date, 6, 2)"/>
        <xsl:value-of select="substring('JanFebMarAprMayJunJulAugSepOctNovDec', 3*($m - 1)+1, 3)"/>
        <xsl:text> </xsl:text>
        <!-- year -->
        <xsl:value-of select="substring($date, 1, 4)"/>
    </li>
  </xsl:template>

</xsl:stylesheet>
