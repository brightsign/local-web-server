
function getAutoPlay(bsp,callback)
{
    //console.log("getAutoPlayURL");
    bsp.callback=callback;
    readCurrentSyncFileList(bsp.syncfile,getAutoPlayFile,bsp);
}


function readCurrentSyncFileList(sUrl,callnext,bsp)
{
    //console.log("doCurrentSyncFileList");
   $.get(sUrl,function(data,status,jqXHR)
   { 
        un=jqXHR.responseText;

        xmlDoc = $.parseXML( un );
        $xml = $( xmlDoc );

        var syncFileList= new Array();

        $xml.find('files').each(function(){
            $(this).children().each(function(){
                var name =$(this).find("name").text();
                var size =$(this).find("size").text();
                var hash =$(this).find("hash").text();
                var link =$(this).find("link").text();
                var fileobj= new syncFileObj(name,size,hash,link);
                syncFileList.push(fileobj);
            });
        });
        bsp.syncFileList=syncFileList;

        printObj(bsp.syncFileList);
        callnext(bsp);
    });
}

function syncFileObj(name,size,hash,link)
{
    this.name=name;
    this.size=size;
    this.hash=hash;
    this.link=link;
}


function findAutoplayFile(bsp)
{
    console.log("findAutoplayFile");
    for(var x=0;x<bsp.syncFileList.length;x++)
    {
        nRet=bsp.syncFileList[x].name.indexOf("autoplay");
        if(nRet>=0)
        {
            bsp.autoplayURL=bsp.syncFileList[x].link;
            printObj(bsp.autoplayURL);
        }
    }
}


function getAutoPlayFile(bsp,callnext)
{

   findAutoplayFile(bsp);
   printObj(bsp.autoplayURL);
   $.get(bsp.autoplayURL,function(data,status,jqXHR)
   { 
        un=jqXHR.responseText;
        bsp.autoplayXML=un;

        var obj= $.xml2json(un);
        for(x=0;x<obj.zones.zone.length;x++)
        {
            console.log("******")
            printObj(obj.zones.zone[x]);

            var pl=obj.zones.zone[x].playlist.states;
            printObj(pl);
        }


    });

}


function zoneObj(x,y,width,height,type,id)
{
    this.x=x;
    this.y=y;
    this.width=width;
    this.height=height;
    this.type=type;
    this.id=id;
}





