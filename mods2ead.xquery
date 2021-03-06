xquery version "1.0";

declare namespace mods="http://www.loc.gov/mods/v3";
declare namespace ead="urn:isbn:1-931666-22-9";
declare namespace xlink="http://www.w3.org/1999/xlink";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace xmldb="http://exist-db.org/xquery/xmldb";

(: declare variable $dbroot := "/db/gnib/mdata/ephemera"; :)
declare variable $dbroot := "/db/gnib/ephemera";

declare variable $callno := "LAE107";

declare function local:gnib-unit($ead as element(), $id as xs:string)
as element()?
{
$ead//ead:c[ead:did/ead:unitid = $id]
};

declare function local:mods2did($mods as element())
as element()*
{
let $unittitles := for $x in $mods/mods:titleInfo return local:titleInfo2unittitle($x)
let $names      := for $x in $mods/mods:name      return local:name2origination($x)
return <did>{$unittitles,$names}</did>
 
};

declare function local:component-id($subseries as xs:string, $file as xs:string, $pos as xs:integer)
as xs:string
{
    let $prefix := concat($callno, '_c')
    let $id := concat($subseries, $file,$pos)
    let $id := replace($id, '_', '-')
    return concat($prefix, $id)
};

declare function local:titleInfo2unittitle($titleInfo as element()+)
as element()*
{

 let $tstrings := 
  for $ti in $titleInfo 
  let $titles := for $t in $ti/mods:title return normalize-space($t/text())
  let $subtitles := for $t in $ti/mods:subTitle return normalize-space($t/text())
  return string-join(($titles, $subtitles), " ; ")
  
 return <unittitle>{ string-join($tstrings, " ; ") }</unittitle>
};


declare function local:altTitleInfo2odd($titleInfo as element()+)
as element()*
{

 let $tstrings := 
  for $ti in $titleInfo 
  let $titles := for $t in $ti/mods:title return normalize-space($t/text())
  let $subtitles := for $t in $ti/mods:subTitle return normalize-space($t/text())
  return string-join(($titles, $subtitles), " ; ")
  
 return <odd>alternate title: { string-join($tstrings, " ; ") }</odd>
};


declare function local:name2origination($name as element())
as element()*
{
	let $parts     := $name/mods:namePart/text()
	let $corpname  := $name[@type='corporate']/mods:namePart/text()
	let $famname   := $name[@type='personal']/mods:namePart[@type='family']/text()
	let $givname   := $name[@type='personal']/mods:namePart[@type='given']/text()
	let $normname  := fn:string-join(($famname, $givname), ', ')
	return
		if ($parts) 
			then 

			if ($name/@type='corporate')
			  then 
			  	<corpname source="local" role = "{$name/mods:role/mods:roleTerm/text()}">{$corpname}</corpname>
			  else
			  	<persname source="local" role = "{$name/mods:role/mods:roleTerm/text()}">
			  		{$normname}
			  	</persname>

		else ()
};

declare function local:mods2component($mrec as element(), $cid as xs:string)
as element()
{
    
    let $date  := $mrec/mods:originInfo/mods:dateCreated/text()
    let $ndate :=
        if ($date castable as xs:date) then xs:date($date)
        else if ($date castable as xs:gYearMonth) then xs:gYearMonth($date)
        else if ($date castable as xs:gYear) then xs:gYear($date)
        else ()
    let $publishers   := $mrec/mods:originInfo/mods:publisher
    let $unittitles := for $x in $mrec/mods:titleInfo[not(@type = 'alternative')] return local:titleInfo2unittitle($x)
    let $odds       := for $x in $mrec/mods:titleInfo[@type='alternative'] return local:altTitleInfo2odd($x)
    let $unitdate   :=
                   if (not(empty($ndate))) then <unitdate normal="{$ndate}">{ $date }</unitdate> else <unitdate>{ $date }</unitdate>
    let $names      := for $x in $mrec/mods:name      return local:name2origination($x)
    let $notes := if ($mrec/mods:note[./text() != "Document extracted from:"]) then
                    <note>{ for $n in $mrec/mods:note 
                    where $n/text() != "Document extracted from:"
                    return <p>{ concat($n/text(), '.') }</p> }</note>
                   else ()
    
    
    return
    <c xmlns="urn:isbn:1-931666-22-9" level="item" id="{$cid}">
      <did>
        { $unittitles }

        { $unitdate }
    
        <origination>
        {
        for $p in $publishers
        return
            <corpname role="cre">{ $p/text() }</corpname>
        }
                { for $name in $mrec/mods:name return local:name2origination($name) }
        </origination>
    

        { $notes }
        
        <langmaterial>
        { 
        for $lang in $mrec/mods:language/mods:languageTerm
        return <language langcode="{ $lang/text() }" />
        }
        </langmaterial>
     
        <dao xlink:type="simple" xlink:role="http://www.loc.gov/METS/" xlink:href="{ replace($mrec//mods:recordIdentifier/text(), "^(.*)\.mods", "$1.mets") }"/>
    </did>

    <controlaccess>
    {
      for $subject in $mrec//mods:subject 
      let $auth := if ($subject/@authority) then $subject/@authority else "local"
      return <subject source="{ $auth }">{string-join($subject/child::*/text(), ' -- ')}</subject>
    }
    <genreform source="aat">ephemera</genreform>
    </controlaccess>
    { $odds }
    </c>
};

(: This xquery generates a new EAD document from the GNIB MODS records and the old GNIB EAD. :)


let $oldead := doc('/db/gnib/gnib.ead.xml')/ead:ead
return
<ead xmlns="urn:isbn:1-931666-22-9" xmlns:xlink="http://www.w3.org/1999/xlink">
{ $oldead/ead:eadheader }
<archdesc level="collection">
{ $oldead/ead:archdesc/ead:did }
<dsc type="combined">
<c level="series">
{ $oldead/ead:archdesc/ead:dsc/c[@level='series'][1]/ead:did }
{ $oldead/ead:archdesc/ead:dsc/c[@level='series'][1]/ead:scopecontent }
{ $oldead/ead:archdesc/ead:dsc/c[@level='series'][1]/ead:arrangement }
{

for $subseries in xmldb:get-child-collections($dbroot) order by $subseries
return

<c level="subseries">
{ 
 let $did := local:gnib-unit($oldead, $subseries)/ead:did
 return if ($did) then $did else <did><unittitle>UNSPECIFIED</unittitle></did>
}

{ local:gnib-unit($oldead, $subseries)/ead:scopecontent }

{
for $file in xmldb:get-child-collections(concat($dbroot, '/', $subseries)) order by $file
return 
<c level="file">
{ 
 let $did := local:gnib-unit($oldead, $file)/ead:did
 return if ($did) then $did else <did><unittitle>UNSPECIFIED</unittitle></did>
}

{
for $item at $pos in collection(concat($dbroot, '/', $subseries, '/', $file))//mods:mods
(: let $cid := concat($callno,'_c',$subseries,$file,$pos) :)
let $cid := local:component-id($subseries,$file,$pos)
return local:mods2component($item, $cid)
}

</c>
}
</c>

}
</c>
<!-- End of computed section. -->

{ $oldead/archdesc/dsc/c[@level='series'][2] }
{ $oldead/archdesc/dsc/c[@level='series'][3] }
{ $oldead/archdesc/dsc/c[@level='series'][4] }

</dsc>
</archdesc>
</ead>