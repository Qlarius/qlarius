// comments box on story pages
jQuery(document).ready(function($) {
	
	//comment form submission
	$('body').on('click', '.sno-comments-wrap form#commentform input#submit[type="submit"]', function(e) {
		$(this).val('Submitting comment...')		
	})
	
	// story liking mechanism
	// on load, check the cookie to see if this post has been liked. If so, flag it with a data attibute so that other actions can be based on this

	setTimeout(function(){ 
		$('.like-side-icon').data('d', 1);
		$('.like-row-icon').data('d', 1);
	}, 2000);

    var z = $('.sno-color-inverter').data();
	$.each( z, function( x, y ) {
		$('.sno-color-inverter').removeAttr('data-' + x);
	});

    function generateUniqueKey() {
        if (window.crypto && window.crypto.randomUUID) {
          return crypto.randomUUID();
        } else {
          return Math.random().toString(36).substr(2, 9);
        }
    }

	
	$('body').on('click', '.like-side-icon, .like-row-icon', function(event) {

	    // if (event.originalEvent && event.originalEvent.isTrusted == true) {} else {
		//     return;
	    // }
	    
        if (!cookiesEnabled()) return;
	    if( $(this).data('d') != 1 ) return;

		var l = '';
		$.each( z, function( a, b ) {
			a += ' '; b += ' ';
			$.each( a.split(''), function( c, d ) {
				l += d + b.split('')[c];	
			})
		})
		
		var r = $(this).data('remember');

		let change;
		let postID = $(this).data('post');
		const button = $(this);

		let cookieName = '498727595015785';
		let testCookie = readCookie(cookieName);
        let parsedCookie = JSON.parse(testCookie);

        let uniqueKey = generateUniqueKey();

        if( testCookie && parsedCookie ) {
            if ( parsedCookie.hasOwnProperty(postID) ) {
                change = 'decrement';
                uniqueKey = parsedCookie[postID];
            } else {
		        change = 'increment';
            }
        } else  {
	        change = 'increment';
        }

		if( change ) {
			r += '\u200B';
			$.ajax({
				url: comment_ajax_object.ajaxurl,
				type: 'POST',
				data: {
					'action': 'recommendpost',
					'postid': postID,
					'change': change,
					'like': l,
					'remember': r,
                    'key': uniqueKey,
					'nonce': comment_ajax_object.nonce
				},
				success:function(results) {	
					if( results != '' ) {
						if( change == 'increment' ) $(button).find('.like-count-bubble').removeClass('like-count-hide').addClass('like-count-display');
						if( change == 'decrement' && results === "0" ) $(button).find('.like-count-bubble').removeClass('like-count-display').addClass('like-count-hide');
						$(button).find('.like-count-bubble').text(results);

                        if( testCookie && parsedCookie ) {
                            if ( parsedCookie.hasOwnProperty(postID) ) {
                                delete parsedCookie[postID];	        
                            } else {
                                parsedCookie[postID] = uniqueKey;
                            }
                            eraseCookie(cookieName);
                            createCookie( cookieName, JSON.stringify(parsedCookie), 30);
                        } else  {
                            const cookieData = {};
                            cookieData[postID] = uniqueKey;
                            createCookie(cookieName, JSON.stringify(cookieData), 30);
                        }
                
					}
				}
				
			})
		}
	});
	
    function cookiesEnabled() {
        document.cookie = "cookietest=1; SameSite=Strict";
        const enabled = document.cookie.indexOf("cookietest=") !== -1;
        document.cookie = "cookietest=1; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Strict";
        return enabled;
      }

	
	// load comments after page load
	/*
	const postid = $('.comments_template_space').data('postid');
	if( postid ) {
		$.ajax({
			url: comment_ajax_object.ajaxurl,
			type: 'POST',
			data: {
				'action': 'loadcomments',
				'postid': postid
			},
			success:function(results) {	
				$('.comments_template_space').replaceWith(results);
			}
		});
	}
	*/
	
	// comment verification mechanisms

    $('body').on('keydown', '.sno-captcha-button, .comment-close-icon, .comments-toggle span, .comment-row-icon-wrap, .like-row-icon-wrap', function(event) {
        if (event.key === 'Enter' || event.keyCode === 13) {
            if( $(this).hasClass('comment-row-icon-wrap') ) {
                $('.comment-row-icon').trigger('click');
            } else if( $(this).hasClass('like-row-icon-wrap') ) {
                $('.like-row-icon').trigger('click');
            } else {
                $(this).trigger('click');
            }
            if( $(this).hasClass('comment-close-icon') ) {
                $('.comment-row-icon-wrap').focus();
            }

        }
    })    
    
	$('.sno-comments-wrap form#commentform input#submit[type="submit"]').prop( 'disabled', true );

    $('a.comment-edit-link').attr('tabindex', '-1');

	setTimeout(function(){ 
		$('.sno-comments-wrap form#commentform p.form-submit').before('<div class="clear"></div><div class="sno-comment-captcha">Are you a robot or a human? <div class="sno-captcha-button sno-robot" role="button" aria-pressed="false" tabindex="0"><i class="fas fa-robot"></i><span class="icon-hidden-text">Robot</span></div><div class="sno-captcha-button sno-human" role="button" aria-pressed="false" tabindex="0"><i class="fas fa-user"></i><span class="icon-hidden-text">Human</span></div></div>');
	}, 5000);
	
	$('body').on('click', '.sno-robot', function() {
		robot_click();
	});

	$('body').on('blur focus keypress paste', '.sno-comments-wrap form#commentform textarea, .sno-comments-wrap form#commentform input', function() {
		if ( $( ".sno-comment-captcha" ).is( ":hidden" ) ) $('.sno-comment-captcha').slideDown();
	});
				
	function robot_click() {
		$('.sno-comments-wrap p.form-submit').slideUp('slow');
		setTimeout( function() {
			$('.sno-comments-wrap p.form-submit').remove();
			$('.sno-comment-captcha').html('Silly robot! Only humans are allowed to comment.');
		}, 1000);
	}
	
	$('body').on('click', '.sno-human', function() {
		var r = $('input#wp-remember');
		$('.sno-comment-captcha').slideUp();
		$('.sno-comments-wrap form#commentform input#submit[type="submit"]').prop( 'disabled', false );
		setTimeout( function() {
			$('.sno-comment-captcha').remove();
			r.val('1\u200B');
		}, 400);
	});

	$('input[name="sno_is_legit_comment"]').attr('name', 'sno_stop_spam');

	$('body').on('click', 'a.comment-reply-link', function() {
		set_spam_verification();
		
	});
	
	$('body').on('focus', 'p.comment-form-email input', function() {
		$('.sno_comment_email_verification').slideDown();
	});
	
	function set_spam_verification() {
		
		var z = $('.sno-comment-id').data();
		$.each( z, function( x, y ) {
			$('.sno-comment-id').removeAttr('data-' + x);
		});
		
		$(document).on('click','.sno-comments-wrap input#submit',function(e){
			
			$('input#sno-verification').attr('value','');
			$.each( z, function( a, b ) {
				a += ' '; b += ' ';
				$.each( a.split(''), function( c, d ) {
					$('input.sno-verification').attr('value', $('input.sno-verification').val() + d + b.split('')[c])	
				})
			})
			$('input#sno-verification').attr('name', 'sno-verifyaction');
		});

	}		
	
	// adjustments for long-form templates
	if( $('.parallaxcontainer').length ) {
		$('.sno-side-icons').hide();
		$(window).scroll(function () {
			if ($(this).scrollTop() > $(window).height()/2 ) {
				$('.sno-side-icons').fadeIn();
			} else {
				$('.sno-side-icons').fadeOut();
			}
		});
	} else {
		$('.sno-side-icons').fadeIn();
	}
	if( $('.sno-side-by-side-container').length ) {
		$('.comment-side-icon').hide();
	}
	
	// staff editing actions
	$('body').on('click', 'button.sno-comment-staff-pick', function() {
		var button = $(this);
		var comment = $(this).closest('li').data('comment');
		var staffpick = ( $(this).closest('li').data('staffpick') == true ) ? 'false' : 'true';
		var text = $(this).data('text');
		jQuery.ajax({
			url: comment_ajax_object.ajaxurl,
			type: 'POST',
			data: {
				'action': 'commentstaffpick',
				'staffpick': staffpick,
				'comment': comment,
				'nonce': comment_ajax_object.nonce
			},
			success:function(results) {	
				if( staffpick == 'true' ) {
					$(button).closest('li').find('p.sno-comment-meta').first().append('<span class="staff_pick"><i class="fas fa-star"></i>' + text + '</span>');
					$(button).find('span.sno-comment-pick-action').text('Unselect');
					$(button).closest('li').data('staffpick', 'true');
					$(button).closest('li').attr('data-staffpick', '1');
				} else {
					$(button).closest('li').find('span.staff_pick').first().remove();
					$(button).find('span.sno-comment-pick-action').text('Select');
					$(button).closest('li').data('staffpick', 'false');
					$(button).closest('li').attr('data-staffpick', '0');
				}
			}
		});
	})

	$('body').on('click', 'button.sno-comment-unapprove', function() {
		var button = $(this);
		var comment = $(this).closest('li').data('comment');
		jQuery.ajax({
			url: comment_ajax_object.ajaxurl,
			type: 'POST',
			data: {
				'action': 'unapprovecomment',
				'comment': comment,
				'nonce': comment_ajax_object.nonce
			},
			success:function(results) {	
				$(button).closest('li').slideUp();
			}
		});
	})
	
	$('body').on('click', 'button.sno-editor-actions', function() {
		if( $(this).closest('.comment-details').find('.sno-comment-actions-editor').is(':visible') ) {
			$('.sno-comment-actions-editor:visible').slideUp();
            $(this).closest('.comment-details').find('.sno-comment-actions-editor').first().find('[tabindex="0"').attr('tabindex', '-1')
		} else {
			$('.sno-comment-actions-editor:visible').slideUp();
			$(this).closest('li').find('.sno-comment-actions-editor').first().slideDown();
            $(this).closest('.comment-details').find('.sno-comment-actions-editor').first().find('[tabindex="-1"').attr('tabindex', '0')
		}
	});
	
	$('body').on('click', 'button.sno-comment-share', function() {
		$('.sno-comment-share-link').hide();
		$(this).closest('li').find('.sno-comment-share-link').first().slideDown();
	});
	if (window.location.href.indexOf("/#open-comments") > -1) {
		$('#sno-comments-side').css('transform', 'none');
	}

	if (window.location.href.indexOf("/#comment-") > -1) {
		const comment_url = window.location.href.split('/#comment-');
		const comment_id = 'li#comment-' + comment_url[1];
		$('#sno-comments-side').css('transform', 'none');
		if( $(comment_id).length ) {
			$(comment_id).addClass('comment-selected');
			const comments_side = $('#sno-comments-side').offset().top;
			const comment_offset = $(comment_id).offset().top
			if( comment_offset == 0 ) {
				const comment_wrapper = Math.abs($('.sno-comments-wrap').offset().top);
				$('#sno-comments-side').animate({
					scrollTop: comment_wrapper - 89
				}, 'slow');
			} else {
				$('#sno-comments-side').animate({
					scrollTop: comment_offset - comments_side - 89
				}, 'slow');
			}
		}
	}
    var commentModalOpen = false;
    $('body').on('keydown', '.comment-row-icon, .sno-story-comment-bar, .sno-comment-bar, .sno-comments, .comment-side-icon, a#commentslink', function(event) {
        if (event.key === 'Enter' || event.keyCode === 13) {
            $('#sno-comments-side').addClass('keyboard-activated');
        } else {
            $('#sno-comments-side').addClass('click-activated');
        }
    });
    $('body').on('click', '.comment-row-icon, .sno-story-comment-bar, .sno-comment-bar, .sno-comments, .comment-side-icon, a#commentslink', function() {
		$('#sno-comments-side').css('transform', 'none');
        $('button.sno-story-comment-bar').attr('aria-expanded', 'true');
        $('#sno-comments-side').attr('aria-hidden', 'false');
        $('.sno-comments-title h3 span').focus();
        $('.comment-form-cookies-consent label').text('Save my name and email in this browser for the next time I comment.')
        commentModalOpen = true;
    });

    $(document).on('keydown', function(event) {
        if (event.key === 'Tab' || event.keyCode === 9) { 
            const specificDiv = $('#sno-comments-side'); 
            const closeBtn = $('.comment-close-icon');            
            const tabbableElements = specificDiv.find('button:not([tabindex="-1"]), a:not([tabindex="-1"]), input:not([disabled], [type="hidden"], [id="spam_stopper"], [id="sno-verification"]), select, textarea, [tabindex]:not([tabindex="-1"])');
            const firstTabbable = tabbableElements.first();
            const lastTabbable = tabbableElements.last();
    
            if (!specificDiv.has(event.target).length) {
                return; 
            }
            if (event.shiftKey && $(event.target).is(firstTabbable)) {
                event.preventDefault();
                closeBtn.focus(); 
            } else if (!event.shiftKey && $(event.target).is(lastTabbable)) {
                event.preventDefault();
                closeBtn.focus();
            }
        }
    });

    $('body').on('click', '.comment-close-icon', function() {
		$('#sno-comments-side').css('transform', 'translateX(110%)');
	});
	$('body').on('focus', 'input.comments-share-thoughts', function() {
		$(this).hide();
		$('.comments-area #respond').fadeIn();
		$('form#commentform textarea').focus();
		$('.sno-comments-policy').slideDown();
		set_spam_verification();
	});
	$('body').on('click', '.comments-area .reply', function() {
		$('input.comments-share-thoughts').hide();
		$('.comments-area #respond').fadeIn();
		$('form#commentform textarea').focus();
		$('.sno-comments-policy').show();
	});
	$('.comments-area p.comment-form-author input').attr({ 'placeholder': 'Name (required)', 'aria-label': 'Name (required)' });
	$('.comments-area p.comment-form-email input').attr({ 'placeholder': 'Email (required)', 'aria-label': 'Email (required)' });
	if( $('.sno-comments-wrap').data('email-verification') == true ) {
		$('.comments-area p.comment-form-email input').after('<div class="clear"></div><div class="sno_comment_email_verification" ><b>Email address verification required</b><br />We will send you an email with a verification link after you submit your comment. You must click that link or your comment will be discarded. Your email address will not be publicly displayed.</div>');
	}
	const placeholder = $('input.comments-share-thoughts').attr('placeholder');
	$('form#commentform textarea#comment').attr({ 'placeholder': placeholder, 'aria-label': placeholder });
	
	// allow readers to recommend comments
	
	function createCookie(name, value, days) {
	    let expires
	
	    if (days) {
	        const date = new Date()
	        date.setTime(date.getTime() + days * 24 * 60 * 60 * 1000)
	        expires = '; expires=' + date.toGMTString()
	    } else {
	        expires = ''
	    }
	    document.cookie =
	        encodeURIComponent(name) + '=' + encodeURIComponent(value) + expires + '; path=/'
	}

	function readCookie(cname) {
	    let name = encodeURIComponent(cname) + '='
	    let ca = document.cookie.split(';')
	    for (let i = 0; i < ca.length; i++) {
	        let c = ca[i]
	        while (c.charAt(0) === ' ') c = c.substring(1, c.length)
	        if (c.indexOf(name) === 0) return decodeURIComponent(c.substring(name.length, c.length))
	    }
	    return null
	}
	function eraseCookie(name) {
	    createCookie(name, '', -1)
	}
	$('body').on('click', 'button.sno-recommended', function() {
		const button = $(this);
		const commentID = $(this).closest('li').data('comment');
		const postID = $(this).closest('li').data('postid');
		const cookieName = '5857203156355';
		const testCookie = readCookie(cookieName);
        const parsedCookie = JSON.parse(testCookie);
        let change
        if( testCookie && parsedCookie ) {
            if( parsedCookie[postID] ) {
	            if( parsedCookie[postID].includes(commentID) ) {
		            change = 'decrement';
		            const arrayIndex = parsedCookie[postID].indexOf(commentID);
		            parsedCookie[postID].splice(arrayIndex, 1);
	            } else {
		            change = 'increment';
		            parsedCookie[postID].push(commentID);
	            }
	        } else {
		        parsedCookie[postID] = [commentID];
	        }
            eraseCookie(cookieName);
            createCookie( cookieName, JSON.stringify(parsedCookie), 30);
        } else  {
	        change = 'increment';
	        const cookieData = { [postID]:[commentID] };
   			createCookie(cookieName, JSON.stringify(cookieData), 30);
        }
		
		jQuery.ajax({
			url: comment_ajax_object.ajaxurl,
			type: 'POST',
			data: {
				'action': 'recommendcomment',
				'comment': commentID,
				'change': change,
				'nonce': comment_ajax_object.nonce
			},
			success:function(results) {	
				$(button).find('span.comment-recommendations').text(results);
			}
		});
	});
	
	// toggle views within comments panel

	function toggle_comment_class(selected) {
		$(selected).closest('.comments-toggle').find('.comments-toggle-active').removeClass('comments-toggle-active');
		$(selected).addClass('comments-toggle-active');
	}
	
	$('body').on('click', '.comments-toggle span', function() {
		if( $(this).hasClass('comments-toggle-active') ) return;
		if( $(this).closest('.comments-toggle').find('.comments-toggle-active').hasClass('comments-reader-picks') ) {
			var comments = $('ul.comment-list > li');
			comments.sort(function(a, b){
			    return $(b).data("order")-$(a).data("order")
			});
			$("ul.comment-list").html(comments);
		}
		if( $(this).hasClass('comments-staff-picks') ) {
			toggle_comment_class($(this));
			$('.sno-comments-wrap li').hide();
			$('.sno-comments-wrap li[data-staffpick="1"]').show();
		}
		if( $(this).hasClass('comments-all') ) {
			toggle_comment_class($(this));
			$('.sno-comments-wrap li').show();
		}
		if( $(this).hasClass('comments-reader-picks') ) {
			toggle_comment_class($(this));
			$('.sno-comments-wrap li').show();
			var comments = $('ul.comment-list > li');
			comments.sort(function(a, b){
			    return $(b).data("recommendations")-$(a).data("recommendations")
			});
			$("ul.comment-list").html(comments);
		}
		if( $(this).hasClass('comments-sort') ) {
			var sort = $('.comments-sort').data('sort');
			$('.comments-sort').data('sort', ( sort == 'newest' ) ? 'oldest' : 'newest' );
			$('.active-sort').text( ( sort == 'newest' ) ? 'Oldest' : 'Newest' );
			var comments = $('ul.comment-list > li');
			comments.sort(function(a, b){
				if( sort == 'newest' ) {
					return $(a).data("order")-$(b).data("order")
				} else {
					return $(b).data("order")-$(a).data("order")
				}
			});
			$("ul.comment-list").html(comments);
		}
		
	})
	
})
