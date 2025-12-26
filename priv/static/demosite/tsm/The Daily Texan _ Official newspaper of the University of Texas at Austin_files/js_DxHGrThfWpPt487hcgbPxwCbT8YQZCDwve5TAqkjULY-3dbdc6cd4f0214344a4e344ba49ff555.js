(function( $ ) {
	$.fn.calendarNav = function() {
		//send this back to the window
		return this.each(function() {
			//grab this into a variable
			var $this = $(this);
			var navButton = $this.find('div.pdf-issue-calendar-nav a');

			//work on the click
			$(navButton).live('click', function(e) {
				//prevent the default
				e.preventDefault();

				//build up the URL for the request
				var url = Drupal.settings.basePath + 'pdf/calendar_ajax/' + $(this).attr('data-month');

				//make the ajax request
				$.getJSON(url, function(data) {
					//grab the HTML bits we'll need
					var html = $(data);
					var newPrev = $(html).find('a.pdf-issue-calendar-nav-prev');
					var newNext = $(html).find('a.pdf-issue-calendar-nav-next');
					var newMonth = $(html).find('h2.pdf-issue-calendar-nav-curmonth');
					var newTable = $(html).find('table.pdf-issue-calendar tbody');

					//replace the navs
					$this.find('a.pdf-issue-calendar-nav-prev').replaceWith(newPrev);
					$this.find('a.pdf-issue-calendar-nav-next').replaceWith(newNext);

					//animate changes to the month & calendar body
					setTimeout(function() {
						//fade out the h2
						$this.find('h2.pdf-issue-calendar-nav-curmonth').fadeOut(200, function() {
							$this.find('h2.pdf-issue-calendar-nav-curmonth').replaceWith(newMonth);
							$(newMonth).fadeIn(200);
						});
					}, 1);

					setTimeout(function() {
						//fade out the calendar
						$this.find('table.pdf-issue-calendar tbody').fadeOut(200, function() {
							$this.find('table.pdf-issue-calendar tbody').replaceWith(newTable);
							$(newTable).fadeIn(200);
						});

					}, 1);
				});
			});
		});
	};
})( jQuery );;
(function ($) {

Drupal.behaviors.dt_issuu = {
	attach: function(context, settings) {
		//make the object have a specified width & height
		$('div#pdf-issuu-wrapper').find('object').css('width', $('div#pdf-issuu-wrapper').width());
		$('div#pdf-issuu-wrapper').find('object').css('height', $('div#pdf-issuu-wrapper').height());
		$('div#pdf-issuu-wrapper').find('embed').css('width', $('div#pdf-issuu-wrapper').width());
		$('div#pdf-issuu-wrapper').find('embed').css('height', $('div#pdf-issuu-wrapper').height());

		//add the calendar functions to the wrapper
		$('div.pdf-issue-calendar-wrapper').calendarNav();
	}
};

//jquery escaped
}(jQuery));;
(function ($) {

Drupal.behaviors.dt_menu = {
	attach: function(context, settings) {
		$('body nav#main-navigation ul.first-level > li').hover(function() {
			//toggle the hover class on the UL
			$(this).toggleClass('hover');
		});
	}
};

Drupal.behaviors.dt_mobile_menu = {
	attach: function(context, settings) {
		$('body.device-mobile nav#mobile-navigation select').change( function() {
			//grab the navigation for the selected one
			var href = '/' + $(this).find("option:selected").val();
			window.location = href;
		});
	}
}

//jquery escaped
}(jQuery));;
/**
 * jQuery Masonry v2.1.05
 * A dynamic layout plugin for jQuery
 * The flip-side of CSS Floats
 * http://masonry.desandro.com
 *
 * Licensed under the MIT license.
 * Copyright 2012 David DeSandro
 */
(function(a,b,c){"use strict";var d=b.event,e;d.special.smartresize={setup:function(){b(this).bind("resize",d.special.smartresize.handler)},teardown:function(){b(this).unbind("resize",d.special.smartresize.handler)},handler:function(a,c){var d=this,f=arguments;a.type="smartresize",e&&clearTimeout(e),e=setTimeout(function(){b.event.handle.apply(d,f)},c==="execAsap"?0:100)}},b.fn.smartresize=function(a){return a?this.bind("smartresize",a):this.trigger("smartresize",["execAsap"])},b.Mason=function(a,c){this.element=b(c),this._create(a),this._init()},b.Mason.settings={isResizable:!0,isAnimated:!1,animationOptions:{queue:!1,duration:500},gutterWidth:0,isRTL:!1,isFitWidth:!1,containerStyle:{position:"relative"}},b.Mason.prototype={_filterFindBricks:function(a){var b=this.options.itemSelector;return b?a.filter(b).add(a.find(b)):a},_getBricks:function(a){var b=this._filterFindBricks(a).css({position:"absolute"}).addClass("masonry-brick");return b},_create:function(c){this.options=b.extend(!0,{},b.Mason.settings,c),this.styleQueue=[];var d=this.element[0].style;this.originalStyle={height:d.height||""};var e=this.options.containerStyle;for(var f in e)this.originalStyle[f]=d[f]||"";this.element.css(e),this.horizontalDirection=this.options.isRTL?"right":"left",this.offset={x:parseInt(this.element.css("padding-"+this.horizontalDirection),10),y:parseInt(this.element.css("padding-top"),10)},this.isFluid=this.options.columnWidth&&typeof this.options.columnWidth=="function";var g=this;setTimeout(function(){g.element.addClass("masonry")},0),this.options.isResizable&&b(a).bind("smartresize.masonry",function(){g.resize()}),this.reloadItems()},_init:function(a){this._getColumns(),this._reLayout(a)},option:function(a,c){b.isPlainObject(a)&&(this.options=b.extend(!0,this.options,a))},layout:function(a,b){for(var c=0,d=a.length;c<d;c++)this._placeBrick(a[c]);var e={};e.height=Math.max.apply(Math,this.colYs);if(this.options.isFitWidth){var f=0;c=this.cols;while(--c){if(this.colYs[c]!==0)break;f++}e.width=(this.cols-f)*this.columnWidth-this.options.gutterWidth}this.styleQueue.push({$el:this.element,style:e});var g=this.isLaidOut?this.options.isAnimated?"animate":"css":"css",h=this.options.animationOptions,i;for(c=0,d=this.styleQueue.length;c<d;c++)i=this.styleQueue[c],i.$el[g](i.style,h);this.styleQueue=[],b&&b.call(a),this.isLaidOut=!0},_getColumns:function(){var a=this.options.isFitWidth?this.element.parent():this.element,b=a.width();this.columnWidth=this.isFluid?this.options.columnWidth(b):this.options.columnWidth||this.$bricks.outerWidth(!0)||b,this.columnWidth+=this.options.gutterWidth,this.cols=Math.floor((b+this.options.gutterWidth)/this.columnWidth),this.cols=Math.max(this.cols,1)},_placeBrick:function(a){var c=b(a),d,e,f,g,h;d=Math.ceil(c.outerWidth(!0)/this.columnWidth),d=Math.min(d,this.cols);if(d===1)f=this.colYs;else{e=this.cols+1-d,f=[];for(h=0;h<e;h++)g=this.colYs.slice(h,h+d),f[h]=Math.max.apply(Math,g)}var i=Math.min.apply(Math,f),j=0;for(var k=0,l=f.length;k<l;k++)if(f[k]===i){j=k;break}var m={top:i+this.offset.y};m[this.horizontalDirection]=this.columnWidth*j+this.offset.x,this.styleQueue.push({$el:c,style:m});var n=i+c.outerHeight(!0),o=this.cols+1-l;for(k=0;k<o;k++)this.colYs[j+k]=n},resize:function(){var a=this.cols;this._getColumns(),(this.isFluid||this.cols!==a)&&this._reLayout()},_reLayout:function(a){var b=this.cols;this.colYs=[];while(b--)this.colYs.push(0);this.layout(this.$bricks,a)},reloadItems:function(){this.$bricks=this._getBricks(this.element.children())},reload:function(a){this.reloadItems(),this._init(a)},appended:function(a,b,c){if(b){this._filterFindBricks(a).css({top:this.element.height()});var d=this;setTimeout(function(){d._appended(a,c)},1)}else this._appended(a,c)},_appended:function(a,b){var c=this._getBricks(a);this.$bricks=this.$bricks.add(c),this.layout(c,b)},remove:function(a){this.$bricks=this.$bricks.not(a),a.remove()},destroy:function(){this.$bricks.removeClass("masonry-brick").each(function(){this.style.position="",this.style.top="",this.style.left=""});var c=this.element[0].style;for(var d in this.originalStyle)c[d]=this.originalStyle[d];this.element.unbind(".masonry").removeClass("masonry").removeData("masonry"),b(a).unbind(".masonry")}},b.fn.imagesLoaded=function(a){function h(){a.call(c,d)}function i(a){var c=a.target;c.src!==f&&b.inArray(c,g)===-1&&(g.push(c),--e<=0&&(setTimeout(h),d.unbind(".imagesLoaded",i)))}var c=this,d=c.find("img").add(c.filter("img")),e=d.length,f="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==",g=[];return e||h(),d.bind("load.imagesLoaded error.imagesLoaded",i).each(function(){var a=this.src;this.src=f,this.src=a}),c};var f=function(b){a.console&&a.console.error(b)};b.fn.masonry=function(a){if(typeof a=="string"){var c=Array.prototype.slice.call(arguments,1);this.each(function(){var d=b.data(this,"masonry");if(!d){f("cannot call methods on masonry prior to initialization; attempted to call method '"+a+"'");return}if(!b.isFunction(d[a])||a.charAt(0)==="_"){f("no such method '"+a+"' for masonry instance");return}d[a].apply(d,c)})}else this.each(function(){var c=b.data(this,"masonry");c?(c.option(a||{}),c._init()):b.data(this,"masonry",new b.Mason(a,this))});return this}})(window,jQuery);;
(function ($) {

Drupal.behaviors.dt_search = {
	attach: function(context, settings) {
		if($('body').hasClass('section-search')) {
			//masonify the elements
			$('section#blog_entry-search-results div.search-blogs-wrapper').masonry({
				itemSelector : '.search-results-blogs',
				gutterWidth : 12,
				isFitWidth : true,
			});

			//tooltip-ify the images
			$('section#image-search-results ul.results-list li a').tooltip();

			//deal with the pager elements
			$('section#article-search-results ul.pager li a').live('click', function(e) {
				//prevent the default action
				e.preventDefault();

				//find which element was clicked
				var clicked = $(this).html();
				var max = Math.ceil(parseInt($('section#article-search-results h2 a').html().toString().split(' ')[0]) / 10);
				var current = parseInt($('li.pager-current').html());

				if($.trim(clicked.toString()) == '« first') { clicked = 1; }
				if($.trim(clicked.toString()) == '‹ previous') { clicked = current - 1; }
				if($.trim(clicked.toString()) == 'next ›') { clicked = current + 1; }
				if($.trim(clicked.toString()) == 'last »') { clicked = max; }

				console.log(max);

				//theme in the new pager
				var url = Drupal.settings.basePath + 'search/pager_html/' + clicked + '/' + max;
				$.getJSON(url, function(data) {
					$('section#article-search-results ul.pager').replaceWith(data);
				});

				//do we need to navigate to a new set of results?
				if(clicked == parseInt(clicked)) {
					//grab the parameters into variables
					var terms = window.location.toString().split('/'); terms = terms[terms.length - 1];
					terms = terms.split('#')[0];
					var start = (clicked * 10) - 10;
					var limit = 10;
					var node_type = 'article';

					var url = Drupal.settings.basePath + 'search/pager/' + terms.replace('#', '') + '/' + start + '/' + limit + '/' + node_type;

					$.getJSON(url, function(data) {
						//put the data into the results area
						$('section#article-search-results ul.results-list').fadeOut('fast', function() {
							$(this).html(data).fadeIn('fast', function() {
								//scroll to the top of the div
								$('body').scrollTop($('section#article-search-results').position().top - 30);
							});
						});
					});
				}
			});
		}
	}
};

//jquery escaped
}(jQuery));;
(function ($) {
	Drupal.behaviors.dt_social = {
		attach: function(context, settings) {
			  if($('div.social_icons').length > 0) {
			  	$('div.social_icons').texanTOC();
			  }
		}
	};
})(jQuery);;
;
