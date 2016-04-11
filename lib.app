module elib/elib-documentation/lib
//This module uses bootstrap templates (elib-bootstrap)
//You are required to extend the entity Documentation with function mayEdit() :Bool in your application

section data

var docStart := Documentation{ key:="doc-start" }

entity Documentation{
  key     : String (id)
  name    : String
  content : WikiText (default="No content available yet")
  partOf  : Documentation (inverse=Documentation.subDocs)
  subDocs : [Documentation]
  
  function getRoot() : Documentation{
    return if(partOf != null) partOf.getRoot() else this;
  }
  function show(){
    replace("content", viewDoc(this));
    runscript("$('.tooltip.fade.top.in, .ui-tooltip-content').remove();");
  }
  function next(): Documentation{ return next(false); }
  function next(levelUp : Bool) : Documentation{
    if(!levelUp && subDocs.length > 0){
      return subDocs[0];
    }else{
      if(partOf != null){
        var idx := partOf.subDocs.indexOf(this);
        if(idx < partOf.subDocs.length-1){
          return partOf.subDocs[(idx+1)];
        } else{
          return partOf.next(true);
        }
      }
    }
    return null;
  }
  function remove(){
    var idx := partOf.subDocs.indexOf(this);
    for(sub in subDocs){
      partOf.subDocs.insert(idx, sub);
    }
    partOf := null;
    this.delete();
  }
  function render() : String{ //html out
    var instrumented := rendertemplate(rawoutput(content));
    return /\[\(([^\)]+)\)\]/.replaceAll("<a href=\"javascript:void(0)\" onclick=\"\\$('#link-$1').click();\" class=\"doc-link\">$1</a>", instrumented);
  }
}

access control rules
rule page doc(*){
  true
}
rule ajaxtemplate editDoc(d : Documentation){
  d.mayEdit()
}
rule ajaxtemplate viewDoc(d : Documentation){
  true
  rule action edit(){
  	d.mayEdit()
  }
}

section pages

page doc(d : Documentation){
  view(d)
}

section templates

template view(d : Documentation){
  placeholder "content"{ viewDoc(d) }
}
ajax template viewDoc(d: Documentation){
  var next := d.next()
  action edit(){
  	replace("content", editDoc(d));
  }
  gridRow{
    gridCol(3){
      docIndex(d)
    } gridCol(9){
      pageHeader3{ output(d.name) }
      rawoutput(d.render())
      hrule
      if(next != null){
        "Next: " submitlink action{ next.show(); }[ignore default class]{ output(next.name) }
      } br
      submitlink edit(){ "edit" }
      
      <script>
        $('.doc-link').each( function(){
          var name = $('#link-'+$(this).text()).text();
          $(this).text( name );
        });
      </script>
    }
  }
}
ajax template editDoc(d : Documentation){
  gridRow{ gridCol(6){
    horizontalForm{
      controlGroup("name"){ input(d.name) }
      controlGroup("key"){ input(d.key) }
      inputWithPreview(d.content, true)
      helpBlock{ "You can create links to other docs by using" <code>"[(doc-key)]"</code> }
      submitlink action{ d.show(); }{ "save" } " "
      submitlink action{ d.show(); rollback(); }{ "cancel" }
      if(d.partOf != null){ pullRight{
        warnAction("Remove", "Do you really want to remove this documentation item?", true){
          submitlink action{
            var parent := d.partOf;
            d.remove();
            parent.show();
          }{"Remove"}
        }
      } }
    }
  } gridCol(6){
    header5{"Preview"}
    wikiTextPreview(d.content, true)
  } }
}
template docIndex(d : Documentation){
  indexNav( d.getRoot(), d )
}
template indexNav(d : Documentation, viewed : Documentation){
  action addSub(){
    d.subDocs.add( Documentation{ name := "New Item" key:="change-me-"+now().getTime() } );
    viewed.show();
  }
  div[class="doc-index-entry"]{
    strong[title="key: " + d.key]{
      if(d == viewed){
        "> " output(d.name)
      }else{
        submitlink action{ d.show(); }[ignore default class, id="link-"+d.key]{ output(d.name) }
      }
    }
    if(d.mayEdit()){ pullRight{
      updown(d, viewed)
      " " submit addSub()[ajax, class="btn-xs"]{ iPlus "Add sub-item "}
    } }
  }  
  for(sub in d.subDocs){
    div[class="indent"]{ indexNav(sub, viewed) }
  }
}

template updown(d : Documentation, viewed : Documentation){
  var parent := d.partOf
  var idx := if(parent != null) parent.subDocs.indexOf(d) else -1
  action levelUp(){
    var parentIdx := parent.partOf.subDocs.indexOf(parent);
    parent.subDocs.remove(d);
    parent.partOf.subDocs.insert(idx+1,d);
    viewed.show();
  }
  action levelDown(){
    var down := parent.subDocs[(idx+1)];
    parent.subDocs.remove(d);
    down.subDocs.insert(0,d);
    viewed.show();
  }
  action up(){
    parent.subDocs.remove(d);
    parent.subDocs.insert(idx-1,d);
    viewed.show();
  }
  action down(){
    parent.subDocs.remove(d);
    parent.subDocs.insert(min(parent.subDocs.length,idx+1),d);
    viewed.show();
  }
  if(parent != null){
    buttonGroup{
      if(parent.subDocs.indexOf(d) > 0){
        submit up()[ajax, class="btn-xs", title="move up"]{ iChevronUp }
      }
      if(idx < parent.subDocs.length-1){
        submit down()[ajax, class="btn-xs", title="move down"]{ iChevronDown }
        submit levelDown()[ajax, class="btn-xs", title="move into next sibling"]{ iImport }
      }
      if(parent.partOf != null){
        submit levelUp()[ajax, class="btn-xs", title="move level up"]{ iLevelUp }
      }
    }
  }
}