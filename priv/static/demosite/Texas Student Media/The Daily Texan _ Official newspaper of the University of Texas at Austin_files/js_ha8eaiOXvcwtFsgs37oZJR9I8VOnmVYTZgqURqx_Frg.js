/*
 * jQuery hashchange event - v1.3 - 7/21/2010
 * http://benalman.com/projects/jquery-hashchange-plugin/
 *
 * Copyright (c) 2010 "Cowboy" Ben Alman
 * Dual licensed under the MIT and GPL licenses.
 * http://benalman.com/about/license/
 */
(function($,e,b){var c="hashchange",h=document,f,g=$.event.special,i=h.documentMode,d="on"+c in e&&(i===b||i>7);function a(j){j=j||location.href;return"#"+j.replace(/^[^#]*#?(.*)$/,"$1")}$.fn[c]=function(j){return j?this.bind(c,j):this.trigger(c)};$.fn[c].delay=50;g[c]=$.extend(g[c],{setup:function(){if(d){return false}$(f.start)},teardown:function(){if(d){return false}$(f.stop)}});f=(function(){var j={},p,m=a(),k=function(q){return q},l=k,o=k;j.start=function(){p||n()};j.stop=function(){p&&clearTimeout(p);p=b};function n(){var r=a(),q=o(m);if(r!==m){l(m=r,q);$(e).trigger(c)}else{if(q!==m){location.href=location.href.replace(/#.*/,"")+q}}p=setTimeout(n,$.fn[c].delay)}$.browser.msie&&!d&&(function(){var q,r;j.start=function(){if(!q){r=$.fn[c].src;r=r&&r+a();q=$('<iframe tabindex="-1" title="empty"/>').hide().one("load",function(){r||l(a());n()}).attr("src",r||"javascript:0").insertAfter("body")[0].contentWindow;h.onpropertychange=function(){try{if(event.propertyName==="title"){q.document.title=h.title}}catch(s){}}}};j.stop=k;o=function(){return a(q.location.href)};l=function(v,s){var u=q.document,t=$.fn[c].domain;if(v!==s){u.title=h.title;u.open();t&&u.write('<script>document.domain="'+t+'"<\/script>');u.close();q.location.hash=v}}})();return j})()})(jQuery,this);;
(function( $ ) {
	$.fn.texanTOC = function( options ) {
		//grab the settings
		var defaults = {
			'left' 	: $('div#page-wrapper').offset().left - $(this).width() - 25,
			'top'  	: 124,
		};
		var opts = $.extend(defaults, options);

		//send this back to the window
		return this.each(function() {

			//grab this into a variable
			var $this = $(this);

			//helper function to set up the page
			function setPosition(top, left) {
				$this.css('position', 'absolute');
				$this.css('left', left);
				$this.css('top', top);
				$this.css('display', 'block');
			}

			//position the TOC when this plugin loads
			setPosition(opts.top, opts.left);
			
			//find the navbar (where we "sticky" the TOC)
			var navPos = $('nav#main-navigation').position().top;

			//position the TOC on window resize!
			$(window).resize(function() {
				//find a new position
				var body_left = $('div#page-wrapper').offset().left - $this.width() - 25;
				setPosition(opts.top, body_left);
			});
			
			//bind an event to scroll function
			$(window).scroll(function(e) {
				//grab the window's top position
				var newTop = -1 * parseInt($('html').offset().top);

				//figure out what to do with the sidebar
				if(newTop <= navPos) {
					//if the new screen top is above the navbar, set the css to 'absolute'
					$this.css('position', 'absolute');
					$this.css('top', opts.top);
				} else {
					//if the new screen top is below the navbar, set the css to 'fixed'
					$this.css('position', 'fixed');
					$this.css('top', navPos - $('nav#main-navigation').height() + 24);
				}
			});

			//handle the clicking on the TOC
			$this.find('a').click(function(e) {
				//prevent the default
				e.preventDefault();

				//grab the href
				var href = $(this).attr('href').toString().replace('#', '');

				//find the new top position
				if(href == 'top') {
					//the new top is the one passed to this plugin
					var newTop = 0;
				} else {
					//find the anchor tag on the page and grab its top
					var newTop = $('body a[name="' + href + '"]').offset().top - 24;
				}

				//scroll to the new top
				$('body').animate({
					scrollTop : newTop
				}, 1400);
			});

		});
	};
})( jQuery );;
(function( $ ) {
	$.fn.tooltip = function( options ) {
		//grab the settings
		var defaults = {
			'background'	: "rgba(0, 0, 0, .85)",
			'foreground'	: "#fff",
			'padding'		: '12px',
			'width'			: '250px',
			'fontStack'		: "'Helvetica Neue', 'Helvetica', 'Arial', sans-serif",
			'fontSize'		: "10pt",
		};
		var opts = $.extend(defaults, options);

		//send this back to the window
		return this.each(function() {

			//grab this into a variable and find the hover text
			var $this = $(this);
			var hoverText = $.trim($this.attr('data-tooltip-text'));

			//make sure this element is relative
			$this.css('position', 'relative');

			//only fire if there's something to fire on!
			if(hoverText != '') {
				//create a div to hover
				var tooltip = $('<div class="tooltip-text">' + hoverText + '</div>');

				//add the styling
				var css = {
					'background-color' 	: opts.background,
					'color'				: opts.foreground,
					'padding'			: opts.padding,
					'font-family'		: opts.fontStack,
					'font-size'			: opts.fontSize,
					'z-index'			: 100,
					'position'			: 'relative',
					'width'				: opts.width,
					'display'			: 'none',
				};
				$(tooltip).css(css);

				//add the tooltip
				$this.append(tooltip);

				//on a hover, add the tooltip
				$this.hover(function(e) {
					$(tooltip).css('left', (-1 * ($(tooltip).width() / 2) + $this.width() / 2));
					$(tooltip).css('top', -1 * $this.height() - $(tooltip).height());
					$(tooltip).fadeIn('fast');
				}, function(e) {
					$(tooltip).fadeOut('fast');
				});
			}

		});
	};
})( jQuery );;
// jQuery escaped
(function ($) {

//Add the function to Drupal behaviors
Drupal.behaviors.authorHover = {
	attach: function (context, settings) {
		//find the max width of the hover
		var liWidth = $("div#story-archive-wrapper ul li").width();
		var ulWidth = liWidth * $("div#story-archive-wrapper ul li").length;

		//find the most we should show
		var maxLeft = ulWidth - $("div#story-archive-wrapper").width();

		//on clicks, jump by a whole story
		$("a#story-archive-left-nav").click(function(e) {
			//prevent anything from happening on click
			e.preventDefault()

			//move left by a whole width
			$("div#story-archive-wrapper ul").css('left', $("div#story-archive-wrapper ul") + liWidth);
		});

		$("a#story-archive-right-nav").click(function(e) {
			//move left by a whole width
			$("div#story-archive-wrapper ul").css('left', $("div#story-archive-wrapper ul") - liWidth);

			//prevent anything from happening on click
			e.preventDefault()
		});

		//add a hover effect to the left button
		var leftTimeout = null;
		$("a#story-archive-left-nav").hover(function() {
			if(leftTimeout == null) {
				leftTimeout = setInterval(leftAnimate, 700);
			}
		});

		//stop the right hover
		$("a#story-archive-left-nav").mouseout(function() {
			clearInterval(leftTimeout);
			leftTimeout = null;

			//force a stoping of the animate
			$("div#story-archive-wrapper ul").stop();
		});

		//actually animate the left scroll
		function leftAnimate() {
			if($("div#story-archive-wrapper ul").position().left <= 0) {
				$("div#story-archive-wrapper ul").animate({
					left: '+=168'
				}, 700, 'linear');
			}
		}

		//add a hover effect to the right button
		var rightTimeout = null;
		$("a#story-archive-right-nav").hover(function() {
			if(rightTimeout == null) {
				rightTimeout = setInterval(rightAnimate, 700);
			}
		});

		//stop the right hover
		$("a#story-archive-right-nav").mouseout(function() {
			//clear the interval
			clearInterval(rightTimeout);
			rightTimeout = null;

			//force a stoping of the animate
			$("div#story-archive-wrapper ul").stop();
		});

		//actually animate the right scroll
		function rightAnimate() {
			//only animate if we won't exceed the max width
			if($("div#story-archive-wrapper ul").position().left - 168 > (maxLeft * -1)) {
				$("div#story-archive-wrapper ul").animate({
					left: '-=168'
				}, 700, 'linear');
			}
		}
	}
};

}(jQuery));;
// jQuery escaped
(function ($) {

//Add the function to Drupal behaviors
Drupal.behaviors.moveHome = {
	attach: function (context, settings) {
		//rearranges the DOM to show things in the right spot
		if($('body').hasClass('device-mobile')) {
			var place = $("div#home-secondary-col2");

			$("div#homepage-headline-queue").insertAfter(place);
			$("div#homepage-editorial-queue").insertAfter(place);
			$("div#block-dt-homepage-blogs-homepage-blocks").insertAfter(place);
		}

		//stretch the latest pdf & latest to fit
		var latestPdfHeight = $('body.section-home div#home-latest-pdf-issue').height();
		var latestStoryHeight = $('body.section-home div#home-latest-stories').height();

		//see which is larger
		if(latestPdfHeight > latestStoryHeight) {
			$('body.section-home div#home-latest-stories').height((latestPdfHeight + 12));
		} else if(latestStoryHeight > latestPdfHeight) {
			$('body.section-home div#home-latest-pdf-issue').height((latestStoryHeight + 12));
		}
	}
};

}(jQuery));;
// jQuery escaped
(function ($) {

//Add the function to Drupal behaviors
Drupal.behaviors.slideshowEffects = {
	attach: function (context, settings) {
		$('.toc').texanTOC({ 'top' : $('div#content').offset().top + 24 });
		$('div.texan-slideshow').texanSlideshow();
	}
};

//Add the function to Drupal behaviors
Drupal.behaviors.resizePage = {
	attach: function (context, settings) {
		//only fire on mobile pages
		if($('body').hasClass('device-mobile')) {
			//make the body width the page of the width
			$('body').css('width', $(window).width() - 2);

			$(window).resize( function() {
				//make the body width the page of the width
				$('body').css('width', $(window).width() - 2);
			});
		}
	}
}

//Place the text ad!
Drupal.behaviors.textAdvertisement= {
	attach: function(context, settings) {
		//grab a paragraph count
		var paragraphCount = $('body section.region-content article').find('p').length;
		var half = Math.floor(paragraphCount / 2) - 1;
		
		//grab the text ad block
		var textAdBlock = $('div#block-openx-10');
		textAdBlock.find('script').remove();
		
		//grab the other details
		var paragraph = $('section.region-content article p').eq(half);
		var newDiv = $('<div id="openx-text-ad"></div>');
		
		//create the new div in the position
		$(paragraph).after(newDiv);
		
		//replace the temp new div with the openx div
		$(newDiv).html(textAdBlock.html());
		
		//remove the old ad
		$(textAdBlock).remove();
	}
}

}(jQuery));;
(function( $ ) {



	$.fn.texanSlideshow = function() {
		//send this back to the window
		return this.each(function() {

			var $this = $(this);

			//do some math on thumb widths
			var wrapperWidth = $this.find("div.slideshow-thumbs").width();
			var thumbWidth = parseInt($this.find("div.slideshow-thumbs ul li.views-row-first").css('width').replace('px', '')) +
				parseInt($this.find("div.slideshow-thumbs ul li.views-row-first").css('margin-right').replace('px', ''));
			var maxWidth = thumbWidth * $this.find("div.slideshow-thumbs ul li").length - wrapperWidth -
				parseInt($this.find("div.slideshow-thumbs ul li.views-row-first").css('margin-right').replace('px', ''));

			//put the active photo listed first

			//grab the NID so we know what to look for
			if(window.location.hash) {
				var image_nid = (window.location.hash.substring(1).split('-')[1]).replace('=', '');
			} else {
				//if the nid doesn't exist, find the NID of the first image
				var image_nid = $this.find('div.slideshow-thumbs ul li.views-row-first a').attr('href').split('-')[1];
			}

			//go to that NID
			replaceNID(image_nid);

			//if for some reason, we don't have an active-image at the end, add it to the first image
			var items = $this.find("div.slideshow-main-image ul li");
			var hasActive = false;

			$.each(items, function(key, value) {
				//look for the image nid
				if($(value).hasClass('active-image')) {
					hasActive = hasActive || true;
				}
			});

			//apply it to the first list item
			if(!hasActive) {
				//alert("hi");
				$('body').find("div.slideshow-main-image ul li.views-row-first").addClass('active-image');
			}

			//put an active class where it needs to go
			applyActiveHref();


			//when an anchor tag is clicked on the thumbnails, flip the image in the slideshow
			$this.find('div.slideshow-thumbs li a').click(function(e) {
				//move the active image
				var newNID = $(this).attr('href').split('-')[1];

				//move to new NID
				replaceNID(newNID);
			});

			//allow for the left anchor click to move
			$this.find('div.slideshow-thumbs-wrapper a.slideshow-nav-left').click(function(e) {
				//prevent the default action
				e.preventDefault();

				//only let the button work if the max width is > the wrapper width
				if((maxWidth + wrapperWidth) > wrapperWidth) {
					//if the left parameter is greater than/equal to left, set it to left
					var curLeft = $this.find('div.slideshow-thumbs-wrapper ul').position().left;

					//if the current left + the thumbWidth >= 0, set it to 0
					if(curLeft + thumbWidth >= 0) {
						$this.find('div.slideshow-thumbs-wrapper ul').animate({
							'left': '0px',
						}, 100);
					} else {
						//animate an entire thumb width left
						$this.find('div.slideshow-thumbs-wrapper ul').animate({
							'left': '+=' + thumbWidth + 'px',
						}, 100);
					}
				}
			});

			//allow for the right anchor click to move
			$this.find('div.slideshow-thumbs-wrapper a.slideshow-nav-right').click(function(e) {
				//prevent the default action
				e.preventDefault();

				//only let the button work if the max width is > the wrapper width
				if((maxWidth + wrapperWidth) > wrapperWidth) {
					//if the left parameter is greater than/equal to left, set it to left
					var curLeft = $this.find('div.slideshow-thumbs-wrapper ul').position().left;

					//if the right will be more than the max width, go to end
					if(curLeft - thumbWidth < (maxWidth * -1)) {
						$this.find('div.slideshow-thumbs-wrapper ul').animate({
							'left': (maxWidth * -1) + 'px',
						}, 100);
					} else {
						//animate an entire thumb width left
						$this.find('div.slideshow-thumbs-wrapper ul').animate({
							'left': '-=' + thumbWidth + 'px',
						}, 100);
					}
				}
			});

			//if the hash changes, we're navigating
			$(window).bind('hashchange', function() {
				//move the active image
				if(window.location.hash) {
					var image_nid = (window.location.hash.substring(1).split('-')[1]).replace('=', '');
				} else {
					//if the nid doesn't exist, find the NID of the first image
					var image_nid = $this.find('div.slideshow-thumbs ul li.views-row-first a').attr('href').split('-')[1];
				}

				//see if the nid exists in this slideshow, and if it does, move it to that slide
				var links = $this.find('div.slideshow-thumbs ul li a');
				var images = new Array();

				//grab a list of images in this array
				$.each(links, function(key, value) {
					images.push($(value).attr('href').toString().replace('#image-', ''));
				});

				//is the element in the array?
				var inSlides = ($.inArray(image_nid, images));

				//if inSlides >= 0, it's in the array
				if(inSlides >= 0) {
					replaceNID(image_nid);

					//scroll to the top of this element
					$('body').animate({
						scrollTop : $this.offset().top
					}, 500);
				}
			});


			//helper function to apply an active to the HREF
			function applyActiveHref() {
				var items = $this.find("div.slideshow-main-image ul li");
				var activeNID = null;
				$.each(items, function(key, value) {
					if($(value).hasClass('active-image')) {
						activeNID = $(value).find("div.slideshow-image").attr('data-image-nid');
					}
				});

				$this.find('div.slideshow-thumbs ul li a').removeClass('active');
				$this.find('div.slideshow-thumbs ul li a[href="#image-' + activeNID + '"]').addClass('active');
			}

			//helper function to move to a new NID
			function replaceNID(newNID) {
				var items = $this.find("div.slideshow-main-image ul li");
				var newLI = null;

				//find the new LI
				$.each(items, function(key, value) {
					if($(value).find("div.slideshow-image").attr('data-image-nid') == newNID) {
						newLI = value;
					}
				});

				//remove all active images
				$(items).removeClass('active-image');
				$(newLI).addClass('active-image');

				//re-set the active
				applyActiveHref();
			}
		});
	};
})( jQuery );;
/**
 * @file
 * A JavaScript file for the theme.
 *
 * In order for this JavaScript to be loaded on pages, see the instructions in
 * the README.txt next to this file.
 */

// JavaScript should be made compatible with libraries other than jQuery by
// wrapping it with an "anonymous closure". See:
// - https://drupal.org/node/1446420
// - http://www.adequatelygood.com/2010/3/JavaScript-Module-Pattern-In-Depth
(function ($, Drupal, window, document, undefined) {


// To understand behaviors, see https://drupal.org/node/756722#behaviors
Drupal.behaviors.my_custom_behavior = {
  attach: function(context, settings) {

    // Place your code here.


// wrap iframe videos with flex-video class
$("#ytplayer").wrap('<div class="flex-video"> </div>');


$("a.secondary-menu-button").on('click',function(){
	$('a.secondary-menu-button').toggleClass('expand');
	$('.wrap-ham').toggleClass('expand');
 	$('#top-nav nav ul#top-menu').slideToggle('fast');
 });





  }
};
})(jQuery, Drupal, this, this.document);
;
