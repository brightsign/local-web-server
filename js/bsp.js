function isBrightSign()
{
    var ua = navigator.userAgent;
    if(ua.indexOf("BrightSign") !=-1) {
        debug_log("isBrightSign: TRUE");
        return true;
    } else {
        debug_log("isBrightSign: FALSE");
        return false;
    }
}


function getPlayerID(callback, sURL)
{
   sURL = typeof sURL !== 'undefined' ? sURL : "/GetID";
   $.get(sUrl,function(data,status,jqXHR)
   { 
        $xml = $( $.parseXML( jqXHR.responseText ));
        
        var n= $unitName = $xml.find( "unitName" ).text();
        var nM=$unitNamingMethod = $xml.find( "unitNamingMethod" ).text();
        var nD=$unitDescription = $xml.find( "unitDescription" ).text();
        var s =$serialNumber = $xml.find( "serialNumber" ).text();
        var f =$functionality = $xml.find( "functionality" ).text();

        var b=new bspIDConstructor(n,nM,nD,s,f);
        callback(b);
    });
   return true;
}


function bspIDConstructor(unitName,unitNamingMethod,unitDescription,serialNumber,functionality)
{
    this.unitName=unitName;
    this.unitNamingMethod=unitNamingMethod;
    this.unitDescription=unitDescription;
    this.serialNumber=serialNumber;
    this.functionality=functionality;
}

function getUserVars(callback, sUrl)
{
   sUrl = typeof sUrl !== 'undefined' ? sUrl : "/GetUserVars";
   var varlist=new Array();
   $.get(sUrl,function(data,status,jqXHR)
   { 
        un=jqXHR.responseText;
        xmlDoc = $.parseXML( un );
        $xml = $( xmlDoc );
        $xml.find('BrightSignVar').each(function(){
            var name=$(this).attr('name');
            var val=$(this).text();
            uv=new userVar(name,val);
            printObj(uv);
            varlist.push(uv);
        });
        callback(varlist);
    });
}

function getUserVarMatch(callback, variable, sUrl)
{
    //console.log("looking for match of: "+variable);
   sUrl = typeof sUrl !== 'undefined' ? sUrl : "/GetUserVars";
   var varlist=new Array();
   $.get(sUrl,function(data,status,jqXHR)
   { 
        un=jqXHR.responseText;
        xmlDoc = $.parseXML( un );
        $xml = $( xmlDoc );
        $xml.find('BrightSignVar').each(function(){
            var name=$(this).attr('name');
            //console.log(name);
            if(name==variable)
            {
                var val=$(this).text();
                varlist.push(val)
            }

        });
        callback(varlist);
    });
}


function userVar(key,value)
{
    this.key=key;
    this.value=value;
}



function getUDPEvents(callback, sUrl)
{
   sUrl = typeof sUrl !== 'undefined' ? sUrl : "/GetUDPEvents";
   $.get(sUrl,function(data,status,jqXHR)
   { 
        un=jqXHR.responseText;
        xmlDoc = $.parseXML( un );
        $xml = $( xmlDoc );

        var recvPort=$xml.find( "receivePort").text();
        var sendPort=$xml.find( "destinationPort" ).text();
        var evlist= new Array();

        $xml.find('udpEvents').each(function(){
            $(this).children().each(function(){
                var label =$(this).find("label").text();
                var action=$(this).find("action").text();
                var ev=new udpevent(label,action);
                evlist.push(ev);
            });
        });

        b=new bspUDPEventList(sendPort,recvPort,evlist);
        callback(b);
    });
}


function sendUDPEvent(callback, sUrl)
{
   sUrl = typeof sUrl !== 'undefined' ? sUrl : "/SendUDP";
   $.get(sUrl,function(data,status,jqXHR)
   { 
        un=jqXHR.responseText;
        xmlDoc = $.parseXML( un );
        $xml = $( xmlDoc );

        var recvPort=$xml.find( "receivePort").text();
        var sendPort=$xml.find( "destinationPort" ).text();
        var evlist= new Array();

        $xml.find('udpEvents').each(function(){
            $(this).children().each(function(){
                var label =$(this).find("label").text();
                var action=$(this).find("action").text();
                var ev=new udpevent(label,action);
                evlist.push(ev);
            });
        });

        b=new bspUDPEventList(sendPort,recvPort,evlist);
        callback(b);
    });
}


function bspUDPEventList(sendPort,recvPort,evList)
{
    this.sendPort=sendPort;
    this.recvPort=recvPort;
    this.events=evList;
}


function udpevent(label,action)
{
    this.label=label;
    this.action=action;
}



function printObj(obj)
{
    debug_log(JSON.stringify(obj));
}




function debug_log(logstr)
{
    if (bsp_utils_enable_debug_logging=true) {
        console.log(logstr);
    }
}









