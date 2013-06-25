function mrssContentObject(url,fileSize,type,medium,duration)
{
    this.url=url;
    this.fileSize=fileSize;
    this.type=type;
    this.medium=medium;
    this.duration=duration;
}


function mrssItem(title,pubDate,link,description,guid,url,fileSize,type,medium,duration,thumbnail)
{
    this.title=title;
    this.pubDate=pubDate;
    this.link=link;
    this.description=description;
    this.guid=guid;
    this.thumbnail=thumbnail;
    this.content=new mrssContentObject(url,fileSize,type,medium,duration);
    this.thumbnail=thumbnail;
}


function mrssPlaylist(url)
{
    this.url=url;
    this.dateFetched=new Date();
    this.items=new Array();
}



function getBSNPlaylist(url,callback)
{
    var qString = 'select * from rss where url=\"'+url+'\"';
    var query = qString;
    var urlBase = 'http://query.yahooapis.com/v1/public/yql?q=';
    var returnFormat = '&format=json';

    var bsnPlaylist=new mrssPlaylist(url);

    jQuery.getJSON(urlBase + encodeURIComponent(query) + returnFormat, function (data) {
    data.query.results.item.forEach(function (item) {
       
        var title=item.title;
        var pubDate=item.pubDate;
        var description=item.description;
        var guid=item.guid;
        var link=item.link;
        var url=item.content.url;
        var fileSize=item.content.fileSize;
        var type=item.content.type;
        var medium=item.content.medium;
        var duration=item.content.duration;
        var thumbnail=item.thumbnail.url;        

        o=new mrssItem(title,pubDate,link,description,guid,url,fileSize,type,medium,duration,thumbnail);
        bsnPlaylist.items.push(o);
      });

      callback(bsnPlaylist);
    });
};

