    jQuery(document).ready(function(){ 
        jQuery("ul.sf-menu").supersubs({ 
            minWidth:    12,   // minimum width of sub-menus in em units 
            maxWidth:    24,   // maximum width of sub-menus in em units 
            extraWidth:  1     // extra width can ensure lines don't sometimes turn over 
        }).superfish({
    		delay:      200,     
        	speed:		'fast'
        });  // call supersubs first, then superfish, so that subs are 
                         // not display:none when measuring. Call before initialising 
                         // containing tabs for same reason. 
			var windowWidth;
        	windowWidth= jQuery(window).width();
        	jQuery( window ).resize(function() {
           		windowWidth = jQuery(window).width();
        	});

        	jQuery('.sf-menu').superfish({
            	onBeforeShow : function (){                 
            		if(!this.is('.sf-menu>li>ul')){
            	        var subMenuWidth = jQuery(this).width();
            	        var parentLi = jQuery(this).parent();                    
            	        var parentWidth = parentLi.width() -8 ;
            	        var subMenuRight = parentLi.offset().left + parentWidth + subMenuWidth;
            	        if(subMenuRight > windowWidth){
            	           	jQuery(this).css('left','auto');
            	            jQuery(this).css('right', parentWidth+'px');
            	        } else {
            	           	jQuery(this).css('right','auto');
            	           	parentWidth +=8;
            	            jQuery(this).css('left', parentWidth+'px');
            	        }
            	    }
            	}
        	});
    }); 
