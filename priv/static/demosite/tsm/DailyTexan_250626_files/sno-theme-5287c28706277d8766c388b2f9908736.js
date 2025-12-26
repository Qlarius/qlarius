// get current date for header/footer elements based on reader's location
jQuery(document).ready(function ($) {
    var mydate = new Date();
    var year = mydate.getYear();
    if (year < 1000) year += 1900;
    var day = mydate.getDay();
    var month = mydate.getMonth();
    var monthWithZero = (mydate.getMonth() + 1).toString().padStart(2, '0');
    var daym = mydate.getDate();
    var dayWithZero = (mydate.getDay() + 1).toString().padStart(2, '0');
    var dayFullArray = new Array("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday");
    var dayArray = new Array("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
    var monthFullArray = new Array("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December");
    var monthArray = new Array("Jan.", "Feb.", "March", "April", "May", "June", "July", "Aug.", "Sept.", "Oct.", "Nov.", "Dec.");

    $('.sno-hac-date').each(function () {
        let format = $(this).data('format').toString().split("");
        let date = '';
        if (format[0] == '1') date += dayArray[day];
        if (format[0] == '2') date += dayFullArray[day];
        if (date) date += ', ';
        if (format[1] == '1') date += monthArray[month];
        if (format[1] == '2') date += monthFullArray[month];
        date += ' ' + daym
        if (format[3] != '0') date += ', ' + year
        $(this).find('time').text(date);
        $(this).find('time').attr('datetime', year + '-' + monthWithZero + '-' + dayWithZero)
    });
});

// for My Calendar plugin
jQuery(document).ready(function ($) {
    $('.mc-main a').each(function () {
        $(this).attr('rel', 'nofollow')
    })
});

// for moving Related Stories Sidebar content to be below the post on mobile devices
jQuery(document).ready(function ($) {
    if ($('.sno-sidebar-related').length && $(window).width() < 600) {
        $('.sno-sidebar-related').appendTo($('.sno-story-related-content-insertion'));
    }
})

// for ImageLinks added 12/2024

jQuery(document).ready(function ($) {
    $('body').on('click', '.dot-wrapper', function (e) {
        if ($(this).hasClass('tooltip-only')) return;
        const id = $(this).data('id');
        const dot = $(this);
        const wrap = $(this).closest('.imagelink-wrap');
        $(wrap).find('.dot-wrapper:not(.dot-wrapper-' + id).hide();
        $(wrap).find('.dot-wrapper-' + id).find('.pulsing-dot, .dot-pulse').fadeOut();
        setTimeout(function () {
            $(wrap).css('overflow', 'hidden');
            $('.dot-wrapper-' + id).find('.dot-overlay').addClass('dot-enlarge');
            setTimeout(function () {
                const overlayContent = $(dot).find('.imagelink-overlay-content').clone().html()
                $(wrap).find('.imagelink-overlay-displayed-content').html(overlayContent);
                $(wrap).find('.imagelink-overlay').show();
                $(wrap).find('.il-close').data('id', id);
                const videoWidth = $('.imagelink-overlay-displayed-content').find('.il-video-full iframe').width();
                $('.imagelink-overlay-displayed-content').find('.il-caption-area').width(videoWidth + 'px');
                $(wrap).find('.overlay-' + id).focus();
            }, 300)
        }, 1)
    })
    $('body').on('click', '.il-close', function () {
        const id = $(this).data('id');
        const wrap = $(this).closest('.imagelink-wrap');
        $(wrap).find('.dot-wrapper-' + id).find('.dot-overlay').removeClass('dot-enlarge')
        $(wrap).find('.imagelink-overlay').fadeOut();
        var $videoIframe = $(wrap).find('.imagelink-overlay iframe');

        if ($videoIframe.length) {
            var src = $videoIframe.attr('src');
            $videoIframe.attr('src', '');
            $videoIframe.attr('src', src);
        }
        setTimeout(function () {
            $(wrap).find('.dot-wrapper').fadeIn();
            $('.dot-wrapper-' + id).find('.pulsing-dot, .dot-pulse').fadeIn();
            $('.dot-wrapper-' + id).focus();
            const $tooltip = $('.dot-wrapper-' + id).find('.dot-tooltip');
            $tooltip.css({
                opacity: 0,
                transform: 'translate(0px, 0px)'
            });

            setTimeout(() => {
                $tooltip.hide();
            }, 300);

        }, 600)
    })

    $(document).on('keydown', '.dot-wrapper', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            $(this).trigger('click')
        }
    });

    $(document).on('keydown', '.il-close', function (e) {
        if (e.key === 'Enter') {
            e.preventDefault();
            $(this).trigger('click')
        }
    });

    $(document).on('keydown', function (e) {
        if (e.key === 'Escape') {
            $('.il-close:visible').trigger('click')
        }
    });


    function positionAndShowTooltip($Dot, $tooltip) {

        $tooltip.hide().css({
            opacity: 0,
            transform: 'translate(0px, 0px)'
        });

        if ($tooltip.text().trim() === "" || $('.preview-panel').length > 0) {
            return;
        }

        const dotPosition = $Dot.position();
        const containerWidth = $Dot.closest('.imagelink-wrap').width();
        const dotCenterX = dotPosition.left + $Dot.width() / 2;
        const dotCenterY = $Dot.height() / 2;

        const tooltipHeight = $tooltip.outerHeight();
        const tooltipTop = dotCenterY - (tooltipHeight / 2);

        if (dotCenterX > containerWidth / 2) {
            $tooltip.css({
                top: tooltipTop + "px",
                left: 'auto',
                right: '100%',
                transform: 'translate(-10px, 0px)',
                opacity: 1,
            });
        } else {
            $tooltip.css({
                top: tooltipTop + "px",
                left: '100%',
                right: 'auto',
                transform: 'translate(10px, 0px)',
                opacity: 1,
            });
        }

        $tooltip.show();
    }

    function hideTooltip($tooltip) {
        $tooltip.css({
            opacity: 0,
            transform: 'translate(0px, 0px)',
        });

        setTimeout(() => {
            $tooltip.hide();
        }, 300);
    }

    // Hover events
    $('.dot-wrapper').hover(
        function () {
            const $Dot = $(this);
            const $tooltip = $Dot.find('.dot-tooltip');
            positionAndShowTooltip($Dot, $tooltip);
        },
        function () {
            const $tooltip = $(this).find('.dot-tooltip');
            hideTooltip($tooltip);
        }
    );

    // Focus and blur events for keyboard navigation
    $(document).on('focus', '.dot-wrapper', function () {
        const $Dot = $(this);
        const $tooltip = $Dot.find('.dot-tooltip');
        positionAndShowTooltip($Dot, $tooltip);
    });

    $(document).on('blur', '.dot-wrapper', function () {
        const $tooltip = $(this).find('.dot-tooltip');
        hideTooltip($tooltip);
    });


});


// for live updates added 06/2024
jQuery(document).ready(function ($) {
    $('body').on('mouseenter', '.live-update-share-wrap', function () {
        $(this).find('.live-update-share-text').show();
        $(this).find('.live-update-share-link').addClass('live-update-share-link-hover');
    });
    $('body').on('mouseleave', '.live-update-share-wrap', function () {
        $(this).find('.live-update-share-text').hide();
        $(this).find('.live-update-share-link').removeClass('live-update-share-link-hover');
    });

    $('body').on('click', '.live-update-share-link', function () {
        $(this).closest('.live-update-share-wrap').find('.live-update-share-text').text('Link Copied');
        var share_link = $(this).data('share-link');
        var $tempInput = $('<input>');
        $('body').append($tempInput);
        $tempInput.val(share_link).select();
        document.execCommand('copy');
        $tempInput.remove();
        $(this).closest('.live-update-share-wrap').find('.live-update-share-link').removeClass('live-update-share-link-hover');
        var clicked = $(this)
        setTimeout(function () {
            $(clicked).closest('.live-update-share-wrap').find('.live-update-share-text').hide();
            var label = $(clicked).closest('.live-update-share-wrap').find('.live-update-share-text')
            $(label).text('Sharing Link');
        }, 1000)
    });

    if (window.location.hash && window.location.hash.includes('live-update')) {
        setTimeout(function () {
            var initialTargetId = window.location.hash;
            var topoffset = ($('#wpadminbar').length > 0) ? 60 : 25;
            var stickyHeaderOffset = 0;
            $('.sno-header-wrap-desktop .sno-header-row-stick').each(function () {
                stickyHeaderOffset += $(this).height();
            })
            $('html, body').animate({
                scrollTop: $(initialTargetId).offset().top - topoffset - stickyHeaderOffset
            }, 1000);
        }, 500);
    }

    // functions for autoupdating timestamps on live updates
    function adjustForGMTOffset(date, gmtOffset) {
        var utc = date.getTime() + (date.getTimezoneOffset() * 60);
        var offsetMilliseconds = gmtOffset * 3600000;
        var adjustedDate = new Date(utc + offsetMilliseconds);
        return adjustedDate;
    }

    function getElapsedTime(dateTimeStamp) {
        var now = new Date();
        var dateTime = new Date(dateTimeStamp);
        dateTime = adjustForGMTOffset(dateTime, -5);
        var difference = now - dateTime;
        var elapsedMinutes = Math.floor(difference / 1000 / 60);
        if (elapsedMinutes <= 0) {
            return 'just now';
        } else if (elapsedMinutes < 60) {
            return elapsedMinutes + ' minute' + (elapsedMinutes === 1 ? '' : 's') + ' ago';
        } else if (elapsedMinutes < 1440) {
            var elapsedHours = Math.floor(elapsedMinutes / 60);
            return elapsedHours + ' hour' + (elapsedHours === 1 ? '' : 's') + ' ago';
        } else if (elapsedMinutes < 10080) {
            var elapsedDays = Math.floor(elapsedMinutes / 60 / 24);
            return elapsedDays + ' day' + (elapsedDays === 1 ? '' : 's') + ' ago';
        }
        return false;
    }

    function updateElapsedTime(updateDiv) {
        var id = $(updateDiv).attr('id');
        var dateTimeStamp = $(updateDiv).find('.live-update-timestamp').data('timestamp-gmt'); // Replace with your timestamp
        var elapsedTime = getElapsedTime(dateTimeStamp);
        if (elapsedTime && $(updateDiv).find('.timestamp-time').is(':visible')) {
            scrollTextOnce(updateDiv, elapsedTime)
        } else if (elapsedTime) {
            scrollTextUpdate(updateDiv, elapsedTime);
        } else {
            $(updateDiv).find('.timestamp-elapsed').text($(updateDiv).find('.timestamp-time').text());
            var intervalID = $('#' + id).data('intervalid');
            clearInterval(intervalID);
        }
    }

    function scrollTextUpdate(updateDiv, elapsedTime) {
        var timeSize = parseInt($(updateDiv).find('.live-update-timestamp').data('time-size'));
        $(updateDiv).find('.timestamp-elapsed-update').text(elapsedTime);
        var text1 = $(updateDiv).find('.timestamp-elapsed').text();
        var text2 = $(updateDiv).find('.timestamp-elapsed-update').text();
        if (text1 != text2) {
            // only animate the timestamp change if the browser tab is active
            // this is needed because inactive browser tabs don't run animations
            if (typeof document.hidden !== "undefined") {
                if (document.hidden) {
                    // Tab is inactive or hidden
                    $(updateDiv).find('.timestamp-elapsed').css('top', '-' + timeSize + 'px');
                    $(updateDiv).find('.timestamp-elapsed-update').css('top', '0px');
                    $(updateDiv).find('.timestamp-elapsed').css('top', timeSize + 'px');
                    $(updateDiv).find('.timestamp-toggle').toggleClass('timestamp-elapsed timestamp-elapsed-update');
                } else {
                    // Tab is active -- animate the change
                    $(updateDiv).find('.timestamp-elapsed').animate({top: '-' + timeSize + 'px'}, 500);
                    $(updateDiv).find('.timestamp-elapsed-update').animate({
                        'top': '0px'
                    }, 500, function () {
                        $(updateDiv).find('.timestamp-elapsed').css('top', timeSize + 'px');
                        $(updateDiv).find('.timestamp-toggle').toggleClass('timestamp-elapsed timestamp-elapsed-update');
                    });
                }
            }
        }
    }

    if (typeof document.hidden !== "undefined") {
        document.addEventListener("visibilitychange", function () {
        });
    }

    function scrollTextOnce(updateDiv, elapsedTime) {
        $(updateDiv).find('.timestamp-elapsed').text(elapsedTime);
        var timeSize = parseInt($(updateDiv).find('.live-update-timestamp').data('time-size'));
        var text1 = $(updateDiv).find('.timestamp-time').text();
        var text2 = $(updateDiv).find('.timestamp-elapsed').text();
        if (text1 != text2) {
            $(updateDiv).find('.timestamp-time').animate({top: '-' + timeSize + 'px'}, 500);
            $(updateDiv).find('.timestamp-elapsed').animate({'top': '0px'}, 500);
            setTimeout(function () {
                $(updateDiv).find('.timestamp-time').hide();
                $(updateDiv).find('.timestamp-time').css('top', timeSize + 'px');
            }, 501);
        }
    }

    function isElementInViewport(el) {
        var $el = $(el);
        var elementTop = $el.offset().top;
        var elementBottom = elementTop + $el.outerHeight();
        var viewportTop = $(window).scrollTop();
        var viewportBottom = viewportTop + $(window).height();
        return elementBottom > viewportTop && elementTop < viewportBottom;
    }

    function checkUpdateDivsViewport() {
        $('body').find('.live-update-wrap.timestamp-check').each(function (i, v) {
            var updateDiv = $(this);
            var id = $(this).attr('id').replace('live-update-', '');
            if (isElementInViewport('#live-update-' + id)) {
                $(this).removeClass('timestamp-check')
                var intervalID = '';
                setTimeout(function () {
                    updateElapsedTime(updateDiv);
                }, 4000);
                setTimeout(function () {
                    intervalID = setInterval(function () {
                        updateElapsedTime(updateDiv)
                    }, 30000);
                }, 8000);
                $('#live-update-' + id).data('intervalid', intervalID);
            }
        });
    }

    checkUpdateDivsViewport()
    $('.live-updates-wrap').data('page-title', document.title)
    $(window).on('scroll resize', function () {
        checkUpdateDivsViewport();
    });

    // Determine whether or not to start the polling mechanism -- only do so if there was an update in the last 24 hours
    var currentTime = Math.floor(Date.now() / 1000);
    var oneDayAgo = currentTime - (24 * 60 * 60);

    $('.live-update-wrap').each(function () {
        var publishedOn = $(this).data('published-on');
        if (publishedOn > oneDayAgo) {
            // show the live coverage banner
            $('.live-coverage-banner-wrap').insertBefore('h1.sno-story-headline').slideDown();
            $('.live-coverage-banner').animate({'opacity': '1'}, 500);
            pollForUpdates();
            return false;
        }
    });

    // move sharing link if both headline and byline are absent
    $('.live-update-wrap').each(function () {
        if ($(this).find('h3').length < 1 && $(this).find('.sno-story-byline').length < 1) {
            $(this).find('.live-update-share-wrap').css({'top': '15px', 'right': '15px'});
        }
        if ($(this).find('.sno-story-byline').length < 1 && $(this).find('.pinned-flag').length < 1) {
            $(this).find('.update-headline-wrap').css({'padding-right': '75px'});
        }
    })

    var pollingIntervalID;
    var stopPollingID;

    function pollForUpdates() {
        // ajax polling system to check server for updates to story every two minutes
        pollingIntervalID = setInterval(function () {
            checkForUpdates()
        }, 120000); // 120000
        // Set the timeout to stop the interval after 1 hour (3600000 milliseconds)
        stopPollingID = setTimeout(function () {
            clearInterval(pollingIntervalID);
            showRefreshButton()
        }, 3600000);
    }

    function checkForUpdates() {

        var post_id = $('.live-updates-wrap').data('post-id');
        var last_rendered = $('.live-updates-wrap').data('last-rendered');
        var rendered_ids = [];

        $('.live-update-wrap').each(function () {
            rendered_ids.push($(this).data('id'));
        });
        $.ajax({
            url: frontend_ajax_object.ajaxurl,
            type: 'POST',
            data: {
                action: 'check_for_updates',
                post_id: post_id,
                last_rendered: last_rendered
            },
            success: function (results) {
                if (results != 'false') {
                    $('.refresh-notification').fadeOut();
                    var update_ids = $.parseJSON(results);
                    var new_updates = [];
                    $.each(update_ids, function (i, v) {
                        if ($.inArray(v, rendered_ids) === -1) {
                            new_updates.push(v);
                        }
                    })
                    var count = new_updates.length;
                    if (count == 0) return;
                    posts_to_retrieve = new_updates.join(',');
                    var message = (count > 1) ? count + ' New Updates' : '1 New Update';
                    $('.update-notification').data('new-updates', posts_to_retrieve)
                    $('.update-notification').attr('data-new-updates', posts_to_retrieve)
                    $('.update-notification').text(message).fadeIn();

                    var currentTimestamp = Math.floor(Date.now() / 1000);
                    $('.live-updates-wrap').data('last-rendered', currentTimestamp)

                    document.title = '(' + count + ') ' + document.title;

                    // stop polling until the user clicks the button
                    if (pollingIntervalID) clearInterval(pollingIntervalID);
                    if (stopPollingID) clearTimeout(stopPollingID)

                } else {
                    if ($('.refresh-notification').is(':visible')) {
                        $('.refresh-notification').text('No Updates Available');
                        setTimeout(function () {
                            $('.refresh-notification').fadeOut();
                        }, 4000);
                        pollForUpdates();
                    }
                }
            }
        });
    }

    $('body').on('click', '.update-notification', function () {
        var update_ids = $(this).data('new-updates');
        $.ajax({
            url: frontend_ajax_object.ajaxurl,
            type: 'POST',
            data: {
                action: 'get_live_updates',
                update_ids: update_ids
            },
            success: function (results) {
                $('.update-notification').fadeOut();
                $('.live-updates-wrap').prepend(results);
                $('html, body').animate({scrollTop: $('.live-updates-wrap').offset().top - 50}, 'slow');
                $('.update-new').slideDown();
                $('.update-new').animate({opacity: 1}, 'slow');
                document.title = $('.live-updates-wrap').data('page-title')

                $('.update-new').each(function () {
                    if ($(this).css('background-color') != $('.sno-story-page').css('background-color')) $(this).addClass('update-add-padding')
                })
                // restart polling
                pollingIntervalID = setInterval(function () {
                    checkForUpdates()
                }, 120000);
                // restart timeout check
                stopPollingID = setTimeout(function () {
                    clearInterval(pollingIntervalID);
                    showRefreshButton()
                }, 3600000);
                // animation for new updates
                setTimeout(function () {
                    $('.update-new').css({borderColor: 'rgba(255, 0, 0, 0)'})
                    $('.update-new').css({borderColor: 'rgba(255, 0, 0, 0)'})
                    setTimeout(function () {
                        $('.live-update-wrap.update-new').toggleClass('update-new update-rendered')
                    }, 1000);
                }, 4000);
            }
        });
    });

    function showRefreshButton() {
        $('.refresh-notification').fadeIn();
    }

    $('body').on('click', '.refresh-notification', function () {
        checkForUpdates();
    })


});

// jQuery(document).ready(function ($) {
//     $('nav').find('li.menu-item-has-children').each(function() {
//         $(this).find('li').attr('tabindex', '0')
//     })
// });

jQuery(document).ready(function ($) {
    $('body').on('click', '.carousel-widget img', function () {
        var href = $(this).closest('.carousel-widget-slide').find('a').attr('href');
        if (href) {
            window.location.href = href;
        }
    })
    $('body').on('click', '.emailshare img', function () {
        var href = $(this).closest('.emailshare').find('a').attr('href');
        if (href) {
            window.location.href = href;
        }
    })
});


// for new story templates added 04/2023
jQuery(document).ready(function ($) {

    // checking to see if an image is both a featured image and inserted into the post
    // if it's both, hide the featured image
    // written to work with both legacy and new templates
    var featuredImageID = $('.photowrap a.modal-photo').data('photo-id')
    if (featuredImageID != undefined) {
        $('.sno-story-body-content img:not(.sno-story-body-media img), span.storycontent img:not(.permalinkphotobox img)').each(function () {
            var classes = $(this).attr('class')
            if (classes != undefined) classes = classes.split(' ');
            $.each(classes, function (i, value) {
                if (value.indexOf("wp-image-") >= 0) {
                    value = value.replace('wp-image-', '')
                    if (value == featuredImageID) {
                        $('.sno-story-body-media, .permalinkphotobox').hide()
                        var story_id = $('.photowrap a.modal-photo').data('story-id')
                        $.ajax({
                            url: frontend_ajax_object.ajaxurl,
                            type: 'POST',
                            data: {
                                action: 'hidefeaturedimage',
                                story: story_id,
                                photo: featuredImageID,
                            },
                            success: function (results) {
                            }
                        })
                    }
                }
            });
        })
    }

    // activate print button for keyboard printing shortcuts
    $('body').on('keydown', function (event) {
        var key = event.keyCode || event.charCode || 0;
        if (key == 80 && event.metaKey == true) {
            if (!$('.sno-story-wrap').length) return;
            if ($('body').hasClass('print-override-deactivate')) return;
            event.preventDefault();
            var url = window.location.href
            if (url.indexOf('?') == -1) {
                url += '?print=true'
            } else {
                url += '&print=true'
            }
            window.location = url
        }
        $('body').on('keydown', function (e) {
            if (e.ctrlKey && e.keyCode == 80) {
                if (!$('.sno-story-wrap').length) return;
                if ($('body').hasClass('print-override-deactivate')) return;
                event.preventDefault();
                var url = window.location.href
                if (url.indexOf('?') == -1) {
                    url += '?print=true'
                } else {
                    url += '&print=true'
                }
                window.location = url
            }
        });
    });
    window.addEventListener('beforeprint', function (e) {
        if (!$('.sno-story-wrap').length) return;
        if ($('body').hasClass('print-override-deactivate')) return;
        e.preventDefault
        var url = window.location.href
        if (url.indexOf('?') == -1) {
            url += '?print=true'
        } else {
            url += '&print=true'
        }
        window.location = url
    });


    $('.sno-story-body-content figure.wp-caption').each(function (i, el) {
        $(el).css('max-width', $(el).css('width'))
        $(el).css('width', 'auto')
    });

    // full-size photos on immersive templates -- add parallax effect
    $('.add-parallax img.size-full').each(function () {
        if ($(this).attr('width') >= $(window).width()) $(this).addClass('image-parallax');
    })

    // for infobox accordions
    $('body').on('click', '.infobox-segment-title-accordion', function () {
        if ($(this).closest('.infobox-segment').find('.infobox-segment-body').is(':visible')) {
            $(this).closest('.infobox-segment').find('.infobox-segment-body-wrap').slideUp();
        } else {
            $(this).closest('.sno-infobox').find('.infobox-segment-body-wrap').slideUp();
            $(this).closest('.infobox-segment').find('.infobox-segment-body-wrap').slideDown();
            $(this).closest('.sno-infobox').find('.infobox-toggle').removeClass('fa-minus').addClass('fa-plus');
        }
        $(this).closest('.infobox-segment').find('.infobox-toggle').toggleClass('fa-minus fa-plus');
    });


    // for related stories carousel on story pages
    $('.related-carousel-list').each(function () {
        $(this).flexslider({
            animation: "slide",
            animationLoop: true,
            controlNav: false,
            customDirectionNav: $(".rcl-nav .custom-navigation span"),
            slideshow: false,
            itemMargin: 10,
            touch: true,
            itemWidth: 375,
            minItems: 1,
            move: 1,
            maxItems: 5
        });
    });
    var TB_CurrentScroll = 0;
    var TB_NextScroll = 0;
    var isChanging = false
    $(window).scroll(function (e) {
        TB_CurrentScroll = TB_NextScroll;
        TB_NextScroll = $(this).scrollTop();

        if (TB_NextScroll < TB_CurrentScroll && $(document).scrollTop() > 300) {  // scrolling up on the page causes it to display
            if ($('.sno-story-related-content-carousel').is(":hidden")) {
                $('.sno-story-related-content-carousel').show();
                $('.sno-story-related-content-carousel').stop().animate({bottom: '0'}, {duration: 300, queue: false});
            }
        } else if ((TB_NextScroll > TB_CurrentScroll && $(document).scrollTop() > 300) || $(document).scrollTop() < 10 && isChanging == false) { // scrolling down on the page causes it to hide
            isChanging = true;
            $('.sno-story-related-content-carousel').stop().animate({
                bottom: '-120px'
            }, 200, function () {
                $('.sno-story-related-content-carousel').hide();
                isChanging = false;
            });
        }
    });


    if ($('.related-bottom-drawer').length) {
        var window_position = $(window).scrollTop();
        var window_height = $(window).height();
        var footerTop = $('.footer').offset().top - window_height;

        $(window).scroll(function () {
            var scroll = $(window).scrollTop();
            if ($('.sno-slideshow-segment').length) {
                const lastSegment = $('.sno-slideshow-segment').last().offset().top;
                if (scroll > lastSegment && !$('.bottom-drawer-header').is(':visible') && footerTop > scroll) {
                    $('.bottom-drawer-header').slideDown();
                }
                if ((scroll < lastSegment && $('.bottom-drawer-header').is(':visible')) || footerTop < scroll) {
                    $('.bottom-drawer-header').slideUp();
                    $('.related-term-container').slideUp();
                    $('.bottom-drawer-background').removeClass('bottom-drawer-background-active');
                    $('.related-bottom-drawer').removeClass('hide-shadow');
                    $('.bds-arrows').fadeOut();
                }
            }
            if (!$('.sno-slideshow-segment').length) {
                if (scroll < 200) {
                    $('.bottom-drawer-header').slideUp();
                    $('.related-term-container').slideUp();
                    $('.bottom-drawer-background').removeClass('bottom-drawer-background-active');
                    $('.related-bottom-drawer').removeClass('hide-shadow');
                    $('.bds-arrows').fadeOut();
                } else if (scroll > (window_height / 2) && !$('.bottom-drawer-header').is(':visible') && footerTop > scroll) {
                    $('.bottom-drawer-header').slideDown();
                }
            }
            // if( !$('.sno-slideshow-segment').length && footerTop < scroll ) {
            //     $('.bottom-drawer-header').slideUp();
            //     $('.related-term-container').slideUp();
            //     $('.bottom-drawer-background').removeClass('bottom-drawer-background-active');
            //     $('.related-bottom-drawer').removeClass('hide-shadow');
            //     $('.bds-arrows').fadeOut();
            // }
            window_position = scroll;
        });
    }


    // end functions for related stories in bottom drawer on story page
    if ($('img.image-parallax').length > 0) {
        var images = document.querySelectorAll('img.image-parallax');
        new simpleParallax(images);
    }

    // for fade image effect for story segment slideshows
    var slideshow_photos = $('.sno-story-photo-fade')
    slideshow_photos.each(function (i, el) {
        var el = $(el)
        if (el.is(':visible')) {
            el.addClass('sno-story-photo-fade-in')
        }
    })
    $(window).scroll(function (event) {
        $('.sno-story-photo-fade').each(function (i, el) {
            const rect = el.getBoundingClientRect();
            var el = $(el)
            if (rect.bottom < $(window).height() / 2) {
                el.removeClass('sno-story-photo-fade-in');
            } else if ($(window).height() - rect.top > $(window).height() / 4) {
                el.addClass('sno-story-photo-fade-in')
            }
        })
    })

    $('.segment-split-text').each(function () {
        if ($(this).find('.segment-split-text-inner').height() + 100 < $(this).height()) $(this).css('display', 'flex');
    })

    $('body').on('click', '.minimize-overlay', function () {
        $(this).closest('.segment-overlay').addClass('segment-overlay-hidden');
        $('body').on('mouseleave', '.segment-overlay', function () {
            $('body').on('mouseenter', '.segment-overlay', function () {
                $(this).removeClass('segment-overlay-hidden');
            });
        });
    })

    center_video()

    function center_video() {
        $('.sno-slideshow-segment .segment-video-immersive').each(function () {
            $(this).css('margin-top', ($(window).height() - $(this).height()) / 2)
        });
    }

    $(window).on('resize', function () {
        center_video()
    });

    // up and down arrows for story segment slideshows
    $('body').on('click', '.down-arrow', function () {
        $('.segment-split-text, .segment-overlay').animate({scrollTop: 0}, 1000);
        $('.segment-overlay').removeClass('segment-overlay-hidden');
        $('.sno-slideshow-segment').each(function (i, el) {
            const rect = el.getBoundingClientRect();
            if (rect.top < 20) return
            const scrollTop = $('html').scrollTop();
            $("html, body").animate({scrollTop: scrollTop + rect.top}, 666);
            return false;
        })
    })
    $('body').on('click', '.up-arrow', function () {
        $('.segment-split-text, .segment-overlay').animate({scrollTop: 0}, 1000);
        $('.segment-overlay').removeClass('segment-overlay-hidden');
        if (!$('.sno-header-wrap:visible').length) show_header();
        $($('.sno-slideshow-segment').get().reverse()).each(function (i, el) {
            const rect = el.getBoundingClientRect();
            const scrollTop = $('html').scrollTop();
            if (rect.top < 0) {
                $("html, body").animate({scrollTop: scrollTop + rect.top}, 666);
                return false;
            }
            if (scrollTop < $(window).height() + 100) {
                $("html, body").animate({scrollTop: 0}, 666);
                return false;
            }
        })
    })


    if ($('#wrap').data('post-template') == 'fulltop' || $('#wrap').data('post-template') == 'split') {
        var position = $(window).scrollTop();
        const ss_height = $("div.sno-format-slideshow").height();

        $(window).scroll(function () {
            var scroll = $(window).scrollTop();
            if (scroll < position && !$('.sno-header-wrap:visible').length) {
                show_header();
            }
            if (scroll > ($(window).height() / 2) && !$('.up-arrow:visible').length) {
                $('.up-arrow').fadeIn();
            }
            if (scroll < ($(window).height() / 2) && $('.up-arrow:visible').length) {
                $('.up-arrow').fadeOut();
            }
            if (scroll > ss_height - ($(window).height() / 2) && $('.down-arrow:visible').length) {
                $('.down-arrow').fadeOut();
            }
            if (scroll < ss_height - ($(window).height() / 2) && !$('.down-arrow:visible').length) {
                $('.down-arrow').show();
            }
            position = scroll;
        });
    }
    ;

    function show_header() {
        var desktop_breakpoint = $('#wrap').data('desktop-breakpoint');
        var tablet_breakpoint = $('#wrap').data('tablet-breakpoint');
        var mobile_breakpoint = $('#wrap').data('mobile-breakpoint');
        var site_width = $(window).width();
        if (site_width < mobile_breakpoint) {
            var header_target = '.sno-header-wrap-mobile';
        } else if (site_width < tablet_breakpoint) {
            var header_target = '.sno-header-wrap-tablet';
        } else {
            var header_target = '.sno-header-wrap-desktop';
        }
        if ($(header_target).find('.sno-header-row-stick').length && !$('.sno-slideshow-segment').length) {
            var fixed_element_adjustment = $('#wpadminbar').length && $('#wpadminbar').is(':visible') ? $('#wpadminbar').outerHeight() : 0
            var stick_height = 0
            $(header_target).scrollToFixed({
                marginTop: fixed_element_adjustment + stick_height,
                spacerClass: 'topheaderspacer',
                zIndex: 2000,
            })
            stick_height += $(this).height()
            $(header_target).fadeIn();
        } else {
            $(header_target).show();
        }

    }

    // fixing text in story that didn't get wrapped with p tags
    if ($('#sno-story-body-content').length) {
        var elems = document.getElementById('sno-story-body-content').childNodes;
        for (var i = 0; i < elems.length; i++) {
            var el = elems[i];
            if (el.nodeType === 3 && el.nodeValue.trim().length) {
                const newNode = document.createElement('p');
                const textNode = document.createTextNode(el.nodeValue);
                newNode.appendChild(textNode);
                $(elems[i + 1]).after(newNode)
                $(elems[i]).remove();
            }
        }
    }

    // detect if sno ad collides with any elements within the post story   
    var story_p = $('.sno-story-body-content > p')
    var story_divs = $('.sno-story-body-content > div, .sno-story-body-content > figure');
    if (story_p.length > 1) {
        $.each(story_p, function () {
            $.each(story_divs, function (index, value) {
                var sno_ad = $('.sno-ad');
                if (sno_ad.length < 1) return;
                if ($(value).hasClass('sno-ad')) return;
                if (collision($(sno_ad), $(value)) == true) {
                    var next_ps = sno_ad.nextAll('p');
                    $.each(next_ps, function (index, value) {
                        if ($(this).text().trim().length) {
                            sno_ad.insertAfter($(this));
                            return false;
                        }
                    })
                    return false;
                }
            });
        })
    }
    // detect if a slideshow or infobox inserted into the story is colliding with the featured image
    var story_featured = $('.sno-story-body-content .sno-story-body-media');
    var story_slideshow = $('.sno-story-body-content .slideshowwrap');
    if (story_slideshow.length && story_featured.length) {
        $.each(story_slideshow, function (index, value) {
            if (collision($(story_featured), $(value)) == true) {
                story_featured.hide();
            }
        })
    }

    // detect if a slideshow or infobox inserted into the story is colliding with the featured image
    var story_featured = $('.sno-story-body-content .sno-story-body-media');
    var story_infobox = $('.sno-story-body-content .sno-infobox');
    if (story_infobox.length && story_featured.length) {
        $.each(story_infobox, function (index, value) {
            if (collision($(story_featured), $(value)) == true) {
                story_featured.hide();
            }
        })
    }

    function collision($div1, $div2) {
        var x1 = $div1.offset().left;
        var y1 = $div1.offset().top;
        var h1 = $div1.outerHeight(true);
        var w1 = $div1.outerWidth(true);
        var b1 = y1 + h1;
        var r1 = x1 + w1;
        var x2 = $div2.offset().left;
        var y2 = $div2.offset().top;
        var h2 = $div2.outerHeight(true);
        var w2 = $div2.outerWidth(true);
        var b2 = y2 + h2;
        var r2 = x2 + w2;

        if (b1 < y2 || y1 > b2 || r1 < x2 || x1 > r2) return false;
        return true;
    }

    $('.sno-story-wrap').find('.slideshowwrap').each(function () {
        var image_ratio = $(this).data('ratio')
        var width = $(this).width();
        var height = $(this).height();
        var photo_width = $(this).find('img').data('width');
        var photo_height = $(this).find('img').data('height');
        if (photo_height < height && photo_width < width) return;
        if (height != 0 && width != 0) {
            var area_ratio = (width / height).toFixed(2)
            if (Math.abs(image_ratio - area_ratio) < 0.25) $(this).find('img').css({'object-fit': 'cover'})
        }
    })

    $('body').on('click', '.byline-photo', function () {
        var link = $(this).data('link');
        if (link) {
            window.location = link
        }
    });
    $('body').on('click', '.related-story.preview-card, .contributor-area', function () {
        var link = $(this).find('a').attr('href')
        if (link) {
            window.location = link
        }
    })
    $('.sno-story-related-content').find('img.scale').each(function () {
        var image_ratio = $(this).data('ratio')
        var width = $(this).closest('.related-story-photo').width();
        if ($(this).closest('.column-count-1').length) {
            var height = $(this).closest('.related-story-photo-area').height();
        } else {
            var height = $(this).closest('.related-story-photo-area').height() - $(this).closest('.related-story-photo-area').find('.related-story-headline').height();
        }
        if (height != 0 && width != 0) {
            var area_ratio = (width / height).toFixed(2)
            if (Math.abs(image_ratio - area_ratio) < 0.25) $(this).css({'object-fit': 'cover'})
        }
    })
    // SNO Story Element - Story Collection
    $('.sno-collection').find('img.scale').each(function () {
        var image_ratio = $(this).data('ratio')
        var shape = $(this).data('shape');
        var width = $(this).closest('div').width();
        if (shape === undefined) {
            var height = $(this).closest('div').height();
        } else {
            var height = (shape == 'Horizontal') ? width * .66 : width;
        }
        if (height != 0 && width != 0) {
            var area_ratio = (width / height).toFixed(2)
            if (Math.abs(image_ratio - area_ratio) < 0.25) $(this).css({'object-fit': 'cover'})
        }
    })
    $('body').on('mouseenter', '.collection-grid.preview-card', function () {
        $(this).find('.collection-grid-overlay').css('opacity', 1);
    });
    $('body').on('mouseleave', '.collection-grid.preview-card', function () {
        $(this).find('.collection-grid-overlay').css('opacity', 0);
    });

    // opening up collection
    $('body').on('click', '.collection-tile.preview-card, .collection-grid.preview-card, a.collection-title', function () {
        const link_type = $(this).closest('.collection-area').data('link-type');
        $('.modal-story-collection').fadeIn();
        if (link_type == 'story') {
            var link = $(this).find('a').attr('href')
            if (link === undefined) link = $(this).attr('href');
            if (link) {
                window.location = link
            }
            return false;
        } else {
            var parent_id = $(this).closest('.snopostid').data('post-id');
            if (parent_id === undefined) $parent_id = 0;
            var postid = $(this).data('postid');
            if (postid === undefined) postid = $(this).closest('.collection-grid-item-wrap').data('postid');
            var collection = $(this).closest('.collection-area').data('collection-ids')
            var collection_title = $(this).closest('.collection-area').data('collection-title')

            $.ajax({
                url: frontend_ajax_object.ajaxurl,
                type: 'POST',
                data: {
                    action: 'getcollection',
                    story: postid,
                    parent_id: parent_id,
                    collection: collection,
                    collection_title: collection_title,

                },
                success: function (results) {
                    $('.remodal-collection-inner-container').replaceWith(results)
                    var scrollDistance = $(document).scrollTop();
                    $('#wrap').addClass('lockposition')
                    $('#wrap').data('scrolled', scrollDistance)

                    $('.flexslider').animate({opacity: 1}, {duration: 'slow'})
                    $('.flex-container').css('background', 'unset')

                    $('.modal-story-collection').find('#collection-thumbnails').flexslider({
                        animation: 'slide',
                        controlNav: false,
                        customDirectionNav: $('.modal-story-collection').find('#sfi-thumbnav span'),
                        animationLoop: true,
                        slideshow: false,
                        itemWidth: 300,
                        itemMargin: 20,
                        touch: true,
                    })

                    $('.modal-story-collection').find('.infobox-carousel').each(function () {
                        var infobox_id = $(this).closest('.sno-infobox').data('id');
                        $(this).flexslider({
                            animation: "slide",
                            animationLoop: false,
                            controlNav: true,
                            customDirectionNav: $('.modal-story-collection').find('.sno-infobox-' + infobox_id + ' .custom-navigation span'),
                            slideshow: false,
                            itemMargin: 0,
                            touch: true,
                            itemWidth: 800,
                            minItems: 1,
                            move: 1,
                            maxItems: 1
                        });
                    });

                    if (typeof initialize_countdown === "function") initialize_countdown();
                    if (typeof initialize_polls === "function") initialize_polls();
                    if (typeof initialize_quiz === "function") initialize_quiz();
                    if (typeof initialize_test === "function") initialize_test();
                    if (typeof initialize_sno_infographic === "function") initialize_sno_infographic();
                    // if( typeof Ot === "function" ) Ot();
                    initialize_flipbooks();

                    var thumbAreaWidth = $('.modal-story-collection').find('#collection-thumbnails').width()
                    var thumbRowWidth = 320 * $('.modal-story-collection').find('#collection-thumbnails li').length
                    if (thumbRowWidth < thumbAreaWidth) {
                        $('.modal-story-collection').find('.sfi-thumbnails').width(thumbRowWidth)
                    }
                    setTimeout(function () {
                        check_thumbnail_nav(postid)
                    }, 333)

                },
            })
            return false;
        }
    })

    function check_thumbnail_nav(postid) {
        if ($('.sfi-thumb[data-postid="' + postid + '"]').offset().left < 0) {
            $('.sfi-thumb-navigation-area .flex-prev').trigger('click')
        } else if ($('.sfi-thumb[data-postid="' + postid + '"]').offset().left + $('.sfi-thumb[data-postid="' + postid + '"]').width() > $(document).width()) {
            $('.sfi-thumb-navigation-area .flex-next').trigger('click')
        }
    }

    // selecting a new story in an open collection
    $('body').on('click', '#collection-thumbnails .sfi-thumb', function () {
        postid = $(this).data('postid')
        getCollectionStory(postid)
    })

    $('body').on('click', '.modal-story-collection .slideshow_left, .modal-story-collection .slideshow_right', function () {
        const current = $('.collection-viewer-body').data('visible-story')
        var collection = $('.sfi-thumb-navigation-area li.sfi-thumb').map(function () {
            return $(this).data('postid');
        }).get();

        if ($(this).hasClass('slideshow_right')) collection = collection.reverse()
        const first = collection[0];
        const last = collection[collection.length - 1];
        var prev = 0;
        var postid = 0;
        $.each(collection, function (index, value) {
            if (value == first && value == current) {
                postid = last;
            } else if (value == current) {
                postid = prev;
            }
            prev = value;
        });
        getCollectionStory(postid)
        check_thumbnail_nav(postid)

        // scroll the thumbnail navigation if newly clicked story is offscreen
    });

    function getCollectionStory(postid) {
        $('.collection-viewer-transition').addClass('collection-viewer-transition-active');
        $('.sfi-thumb').removeClass('active-story');
        $('.sfi-thumb[data-postid="' + postid + '"]').addClass('active-story');
        $.ajax({
            url: frontend_ajax_object.ajaxurl,
            type: 'POST',
            data: {
                action: 'getcollectionstory',
                story: postid,
            },
            success: function (results) {
                $('.collection-viewer-body').replaceWith(results)
                $('.collection-viewer-wrap').scrollTop(0);
                $('.collection-viewer-transition').removeClass('collection-viewer-transition-active');
                $('.modal-story-collection').find('.infobox-carousel').each(function () {
                    var infobox_id = $(this).closest('.sno-infobox').data('id');
                    $(this).flexslider({
                        animation: "slide",
                        animationLoop: false,
                        controlNav: true,
                        customDirectionNav: $('.modal-story-collection').find('.sno-infobox-' + infobox_id + ' .custom-navigation span'),
                        slideshow: false,
                        itemMargin: 0,
                        touch: true,
                        itemWidth: 800,
                        minItems: 1,
                        move: 1,
                        maxItems: 1
                    });
                    $(this).css('opacity', '1');
                });
                if (typeof initialize_countdown === "function") initialize_countdown();
                if (typeof initialize_polls === "function") initialize_polls();
                if (typeof initialize_quiz === "function") initialize_quiz();
                if (typeof initialize_test === "function") initialize_test();
                if (typeof initialize_sno_infographic === "function") initialize_sno_infographic();
                // if( typeof Ot === "function" ) Ot();
                initialize_flipbooks();
            },
        })
    }


    // closing collections
    $('body').on('click', '.modal-story-collection .sfi-return-to-story, .modal-story-collection .sno-overlay-close', function () {
        $('#wrap').removeClass('lockposition')
        $(document).scrollTop($('#wrap').data('scrolled'));
        $(this).closest('.modal-story-collection').fadeOut();
        setTimeout(function () {
            $('.collection-viewer-body').fadeOut();
            $('#collection-thumbnails').fadeOut();
        }, 1000)
    });

    // function to initialize any flipbooks found in collection stories
    function initialize_flipbooks() {
        canvases = jQuery("body").find(".sno-pdf-flipbook-canvas")
        canvases.each(function () {
            const flipbook = jQuery(this).find("#sno-flipbook")
            const width = flipbook.data("width")
            const aspect_ratio = flipbook.data("aspect-ratio")
            const arrowLeft = jQuery(this).find(".sno-flipbook-arrow-left")
            const arrowRight = jQuery(this).find(".sno-flipbook-arrow-right")
            flipbook.turn({
                width: width - 62,
                height: (width - 62) / aspect_ratio,
                elevation: 50,
                gradients: false,
                autoCenter: true,
            })
            flipbook.bind("turning", function (_event, page) {
                const atFirstPage = page == 1
                const atLastPage = page == jQuery(this).turn("pages")
                if (atFirstPage) {
                    arrowLeft.addClass("disabled")
                } else {
                    arrowLeft.removeClass("disabled")
                }
                if (atLastPage) {
                    arrowRight.addClass("disabled")
                } else {
                    arrowRight.removeClass("disabled")
                }
            })
            flipbook.addClass("animated")
            arrowLeft.click(function () {
                flipbook.turn("previous")
            })
            arrowRight.click(function () {
                flipbook.turn("next")
            })
            window.addEventListener("keydown", (ev) => {
                if (ev.key == "ArrowLeft") flipbook.turn("previous")
                if (ev.key == "ArrowRight") flipbook.turn("next")
            })
        })
    }

    // social icons hover effects
    $('.sno-row-icon').on('mouseenter', function () {
        const hover_style = $(this).closest('.sno-row-icons').data('hover-style');
        const mono = $('.snodo-template-group:visible').find('.icons-mono-color input').val();
        switch (hover_style) {
            case 'Full Color':
                $(this).addClass('hover-full-color');
                break;
            case 'Full Color Inverse':
                $(this).addClass('hover-full-color-inverse');
                break;
            case 'Monochromatic':
                $(this).addClass('monochromatic');
                break;
            case 'Monochromatic Inverse':
                $(this).addClass('monochromatic-inverse');
                break;
        }
    });
    $('body').on('mouseleave', '.sno-row-icon', function () {
        $(this).removeClass('hover-full-color hover-full-color-inverse monochromatic monochromatic-inverse');
    });

    if ($('#wrap').data('post-template') == 'fulltop' || $('#wrap').data('post-template') == 'split') {
        $('.sno-story-media-area-fade').fadeOut('slow');

        $('.sno-row-icons').hide();
        $(window).scroll(function () {
            if ($(this).scrollTop() > $(window).height() / 2) {
                $('.sno-row-icons').fadeIn();
            } else {
                $('.sno-row-icons').fadeOut();
            }
        });
        var wp_adminbar = ($('#wpadminbar').length > 0 && $('#wpadminbar').is(':visible')) ? $('#wpadminbar').height() : 0;

        $('#jump-arrow').click(function () {
            var header_height = ($('.sno-header-wrap:visible').length) ? $('.sno-header-wrap:visible').height() : 0;
            if ($('.sno-story-fulltop-container').length) {
                $('html, body').animate({scrollTop: $('.sno-story-fulltop-container').offset().top - wp_adminbar - header_height}, 500)
            }
            if ($('.sno-story-split-header-area').length) {
                $('html, body').animate({scrollTop: $('.sno-story-split-header-area').offset().top - wp_adminbar - header_height}, 500)
            }
            $('#jump-arrow').fadeOut()
            return false
        })

        jQuery(window).scroll(function () {
            if (jQuery(this).scrollTop() > jQuery(window).height()) {
                jQuery('#jump-arrow').fadeOut()
            } else {
                jQuery('#jump-arrow').fadeIn()
            }
        });
        $('.sno-story-split-image-area').on('mouseenter', function () {
            $(this).find('.fullphoto-overlay').fadeIn();
        });
        $('.sno-story-split-image-area').on('mouseleave', function () {
            $(this).find('.fullphoto-overlay').fadeOut();
        });

    } else {
        $('.sno-row-icons').fadeIn();
    }

});

// carousel adjustment for mobile
jQuery(document).ready(function ($) {
    if ($(window).width() < 600) {
        $('.carousel-widget-slide-beside').width($(window).width() - 20)
    }
})

// snoAds integration
jQuery(document).ready(function ($) {
    if ($('.snods_footer').length) {
        var spot_id = $('.snods_footer').first().data('spot_id')
        var fill = $('.snods_footer').first().data('fill')
        var sno_client_id = $('.snods_footer').first().data('sno_client_id')
        var url = 'https://snoads.com/api/v1/adspot/' + spot_id + '/serve'
        jQuery.get(url, '', function (response) {
            if (response && response.link != null && response.image != null) {
                $('.footerboardwrap .footerimage')
                    .filter(':visible')
                    .html(
                        '<a target="_blank" href="' +
                        response.link +
                        '" class="sno-spot" data-spot-id="' +
                        response.id +
                        '"><img src="' +
                        response.image +
                        '" alt="Related Content" /></a>'
                    )
            } else {
                let rand_num = Math.floor(Math.random() * 2 + 1)
                $('.footerboardwrap .footerimage')
                    .filter(':visible')
                    .html(
                        `<img tabindex="0" aria-label="Additional Content" class="sno-fill" src="https://snoadfills.s3.us-west-2.amazonaws.com/fill-728x90-v${rand_num}.png" alt="Related Content"/>`
                    )
            }
        }).fail(() => {
            if (fill) {
                $('.footerboardwrap .footerimage')
                    .filter(':visible')
                    .html('<img tabindex="0" aria-label="Additional Content" class="sno-fill" src="' + fill + '" alt="Related Content"/>')
            } else {
                let rand_num = Math.floor(Math.random() * 2 + 1)
                $('.footerboardwrap .footerimage')
                    .filter(':visible')
                    .html(
                        `<img tabindex="0" aria-label="Additional Content" class="sno-fill" src="https://snoadfills.s3.us-west-2.amazonaws.com/fill-728x90-v${rand_num}.png" alt="Related Content"/>`
                    )
            }
        })

        $('.footerimage').on('click', '.sno-spot', function () {
            let ad_id = $(this).data('spot-id')
            var url = 'https://snoads.com/api/v1/ad/' + ad_id + '/click'
            jQuery.post(url, '', function (response) {
            })
        })

        $('.footerimage').on('click', '.sno-fill', function () {
            const url = `https://snoads.com/marketplace?site=${sno_client_id}`
            window.open(url, '_blank')
        })
    }
})

jQuery(document).ready(function ($) {

    if ($('.footer .snoads-unplaced').length) {
        if ($('.footer .snoads-unplaced').closest('.sno-designer-area-row').next('.sno-designer-area-row').hasClass('sno-designer-row-fullscreen')) {
            $('.footer .snoads-unplaced').addClass('sno-designer-row-fullscreen');
        }
    }

    if ($('.sno-header-wrap .snoads-unplaced').length) {
        if ($('.sno-header-wrap .snoads-unplaced').closest('.sno-designer-area-row').next('.sno-designer-area-row').hasClass('sno-designer-row-fullscreen')) {
            const bg_color = $('.sno-header-wrap .snoads-unplaced').closest('.sno-designer-area-row').next('.sno-designer-area-row').css("background-color")
            $('.sno-header-wrap .snoads-unplaced').closest('.sno-designer-area-row').css({'background-color': bg_color + '!important'})
        }
    }

});


jQuery(document).ready(function ($) {
    if ($('.snods_sidebar').length) {
        var spot_id = $('.snods_sidebar').first().data('spot_id')
        var fill = $('.snods_sidebar').first().data('fill')
        var sno_ads_id = $('.snods_sidebar').first().data('sno_client_id')

        var url = 'https://snoads.com/api/v1/adspot/' + spot_id + '/serve'
        jQuery.get(url, '', function (response) {
            if (response && response.link != null && response.image != null) {
                $('.sidebarimage')
                    .filter(':visible')
                    .html(
                        '<a target="_blank" href="' +
                        response.link +
                        '" class="sno-spot" data-spot-id="' +
                        response.id +
                        '"><img src="' +
                        response.image +
                        '" alt="Related Content" /></a>'
                    )
            } else {
                let rand_num = Math.floor(Math.random() * 2 + 1)
                $('.sidebarimage')
                    .filter(':visible')
                    .html(
                        `<img tabindex="0" aria-label="Additional Content" class="sno-fill" src="https://snoadfills.s3.us-west-2.amazonaws.com/fill-300x250-v${rand_num}.png" alt="Related Content"/>`
                    )
            }
        }).fail(() => {
            if (fill) {
                $('.sidebarimage')
                    .filter(':visible')
                    .html('<img tabindex="0" aria-label="Additional Content" class="sno-fill" src="' + fill + '" alt="Related Content" />')
            } else {
                let rand_num = Math.floor(Math.random() * 2 + 1)
                $('.sidebarimage')
                    .filter(':visible')
                    .html(
                        `<img tabindex="0" aria-label="Additional Content" class="sno-fill" src="https://snoadfills.s3.us-west-2.amazonaws.com/fill-300x250-v${rand_num}.png" alt="Related Content"/>`
                    )
            }
        })
        $('.sidebarimage').on('click', '.sno-spot', function () {
            let ad_id = $(this).data('spot-id')
            var url = 'https://snoads.com/api/v1/ad/' + ad_id + '/click'
            jQuery.post(url, '', function (response) {
            })
        })

        $('.sidebarimage').on('click', '.sno-fill', function () {
            const url = `https://snoads.com/marketplace?site=${sno_ads_id}`
            window.open(url, '_blank')
        })
    }
})

jQuery(document).ready(function ($) {
    if ($('.snods_leaderboard').length) {
        var spot_id = $('.snods_leaderboard').first().data('spot_id')
        var fill = $('.snods_leaderboard').first().data('fill')
        var sno_ads_id = $('.snods_leaderboard').first().data('sno_client_id')

        var url = 'https://snoads.com/api/v1/adspot/' + spot_id + '/serve'
        jQuery.get(url, '', function (response) {
            if (response && response.link != null && response.image != null) {
                $('.leaderboardimage')
                    .filter(':visible')
                    .html(
                        '<a target="_blank" href="' +
                        response.link +
                        '" class="sno-spot" data-spot-id="' +
                        response.id +
                        '"><img src="' +
                        response.image +
                        '" alt="Related Content" /></a>'
                    )
            } else {
                let rand_num = Math.floor(Math.random() * 2 + 1)
                $('.leaderboardimage')
                    .filter(':visible')
                    .html(
                        `<img tabindex="0" aria-label="Additional Content" class="sno-fill" src="https://snoadfills.s3.us-west-2.amazonaws.com/fill-728x90-v${rand_num}.png" alt="Related Content"/>`
                    )
            }
        }).fail(() => {
            if (fill) {
                $('.leaderboardimage')
                    .filter(':visible')
                    .html('<img tabindex="0" aria-label="Additional Content" class="sno-fill" src="' + fill + '" alt="Related Content" />')
            } else {
                let rand_num = Math.floor(Math.random() * 2 + 1)
                $('.leaderboardimage')
                    .filter(':visible')
                    .html(
                        `<img tabindex="0" aria-label="Additional Content" class="sno-fill" src="https://snoadfills.s3.us-west-2.amazonaws.com/fill-728x90-v${rand_num}.png" alt="Related Content"/>`
                    )
            }
        })
        $('.leaderboardimage').on('click', '.sno-spot', function () {
            let ad_id = $(this).data('spot-id')
            var url = 'https://snoads.com/api/v1/ad/' + ad_id + '/click'
            jQuery.post(url, '', function (response) {
            })
        })

        $('.leaderboardimage').on('click', '.sno-fill', function () {
            // url = 'https://snoads.com/marketplace/' + sno_ads_id
            const url = `https://snoads.com/marketplace?site=${sno_ads_id}`
            window.open(url, '_blank')
        })
    }
})

// scrollToFixed for header elements
jQuery(function ($) {
    var fixed_element_adjustment = $('#wpadminbar').length && $('#wpadminbar').is(':visible') ? $('#wpadminbar').outerHeight() : 0
    var stick_height = 0
    $('.sno-header-row-stick:visible').each(function () {
        $(this).scrollToFixed({
            marginTop: fixed_element_adjustment + stick_height,
            spacerClass: 'topheaderspacer',
            zIndex: 2000,
        })
        stick_height += $(this).height()
    })
    var bottom_stick_height = 0
    $($('.footer .sno-footer-row-stick:visible').get().reverse()).each(function () {
        var row = this
        $(this).scrollToFixed({
            bottom: bottom_stick_height,
            limit: $(row).offset().top,
        })
        bottom_stick_height += $(this).height()
    })
})

// If a draft is being displayed via query string, append all hyperlinks on the page with the query string to keep the user in the draft as they click through the site
jQuery(function ($) {
    $(document).ready(function () {
        if ($('.sno-viewing-draft-notice').length) {
            $('a').each(function () {
                if ($(this).hasClass('draft-live')) return
                if ($(this).closest('#wpadminbar').length) return
                if ($(this).attr('href').indexOf($('.sno-viewing-draft-notice').data('url')) > 0) {
                    var joiner = ($(this).attr('href').includes('?')) ? '&' : '?';
                    $(this).attr('href', $(this).attr('href') + joiner + 'draft=' + $('.sno-viewing-draft-notice').data('draft-id'))
                }
            })
        } else if (window.location.href.indexOf("draft=live") > -1) {
            $('a').each(function () {
                if ($(this).closest('#wpadminbar').length) return
                var joiner = ($(this).attr('href').includes('?')) ? '&' : '?';
                $(this).attr('href', $(this).attr('href') + joiner + 'draft=live')
            })
        }
    })
})

jQuery(function ($) {

    $('body').on('keydown', '.back-to-list', function (e) {
        if (!$('.return-focus-to-item').length) return;
        e.preventDefault();
        $('.return-focus-to-item').focus();
        $('.return-focus-to-item').removeClass('return-focus-to-item')
        $('ul.menu-with-teasers a').attr('tabindex', '0')
    });

    $('ul.menu-with-teasers').on('keyup', function (event) {
        if (event.key === 'Tab' || event.keyCode === 9) {
            if ($(event.target).hasClass('sf-with-ul')) return;

            var visibleCards = $(event.target).closest('ul').find('.menu-ta-wrap .sno-menu-card:visible');
            if (!visibleCards.length) return;
            var lastVisibleCard = visibleCards.last();
            var lastLink = lastVisibleCard.find('a');
            $(lastLink).addClass('last-menu-teaser-headline');
            if ($(event.target).hasClass('last-menu-teaser-headline')) {
                $(event.target).addClass('back-to-list')
                $('.return-focus-to-item').attr('tabindex', '0')

            } else {
                var allLinks = $(event.target).closest('li.menu-item-has-children').find('ul li > a');
                var unfocusedLinks = allLinks.filter(function () {
                    return this !== document.activeElement;
                });
                var tabindex = '0';
                var nextlink = false;
                allLinks.each(function (i, link) {
                    $(link).attr('tabindex', tabindex)
                    if (nextlink == true) {
                        $(link).addClass('return-focus-to-item');
                        nextlink = false;
                    }
                    if (link == document.activeElement) {
                        tabindex = '-1';
                        nextlink = true;
                    }
                })
            }
        }
    });

    // show teasers for selected menus on hover of category or via focus from tabbing
    $('body').on('focus', 'ul.menu-with-teasers .menu-item-object-category a, ul.menu-with-teasers .menu-item-object-page a', function () {
        load_menu_teasers($(this).closest('li'));
    })

    $('body').on('mouseenter', 'ul.menu-with-teasers .menu-item-object-category, ul.menu-with-teasers .menu-item-object-page', function () {
        load_menu_teasers($(this));
    })

    function load_menu_teasers(triggerDiv) {
        var menu_object_id = ''
        $.each($(triggerDiv).attr('class').split(' '), function (index, value) {
            if (/\d/.test(value) == true) {
                menu_object_id = value.replace('menu-item-', '')
                return
            }
        })

        if (menu_object_id == '') return

        $('.menu-ta-inner').empty()
        $('.menu-ta-inner').hide()
        if ($(triggerDiv).find('.menu-ta-inner').length) {
            $(triggerDiv)
                .find('.menu-ta-inner')
                .append(
                    $(triggerDiv)
                        .closest('.sno-designer-area-container')
                        .find('.sub-menu-teaser-display-' + menu_object_id)
                        .clone()
                        .hide()
                )
        } else {
            $(triggerDiv)
                .siblings('li')
                .last()
                .find('.menu-ta-inner')
                .append(
                    $(triggerDiv)
                        .closest('.sno-designer-area-container')
                        .find('.sub-menu-teaser-display-' + menu_object_id)
                        .clone()
                        .hide()
                )
        }
        $('.menu-ta-inner').fadeIn('slow')
        $('.sub-menu .sub-menu-teaser-display-' + menu_object_id).fadeIn()
        $(triggerDiv)
            .find('img.scale')
            .each(function () {
                var image_ratio = $(triggerDiv).data('ratio')
                var width = 220 // this is an approximation
                var height = $(triggerDiv).closest('.sno-story-card-photo-wrap').height()
                if (height != 0 && width != 0) {
                    var area_ratio = (height / width).toFixed(2)
                    if (Math.abs(image_ratio - area_ratio) < 0.25) $(triggerDiv).css({'object-fit': 'cover'})
                }
            })
    }

    // adjust menu markup for menus that have teasers enabled
    function prepare_menus_with_teasers(menu) {
        // special adjustments for the More menu item
        $(menu)
            .find('ul.menu-with-teasers')
            .find('li.menu-more-item-top')
            .find('ul.sub-menu')
            .each(function () {
                $(this).closest('li').removeClass('menu-item-has-children')
                $(this).closest('li').find('a').removeClass('sf-with-ul')
                $(this).remove()
            })
        // removing the ability for the More Menu to have category teasers display -- unless I can figure out how to have one of them display by default
        /*
		$(menu).find('ul.menu-with-teasers').find('ul.sno-hac-menu-more').each(function() {
			$('<li class="menu-ta-wrap"><div class="menu-ta"><div class="menu-ta-inner">Insertion Point</div></div><div class="clear"></div></li>').insertAfter($(this).find('li').last());
			$('.menu-teaser-insertion').replaceWith()
		});
        */
        $(menu)
            .find('ul.menu-with-teasers > li.menu-item-object-category')
            .find('ul.sub-menu')
            .each(function () {
                if ($(this).find('li.menu-item-object-category').length || $(this).closest('li.menu-item-object-category').length) {
                    $(this).closest('li').addClass('sub-menu-teasers')
                    $(
                        '<li class="menu-ta-wrap"><div class="menu-ta"><div class="menu-ta-inner"></div></div><div class="clear"></div></li>'
                    ).insertAfter($(this).find('li').last())
                }
            })
        $(menu)
            .find('ul.menu-with-teasers > li.menu-item-object-page')
            .find('ul.sub-menu')
            .each(function () {
                var menu_object_id = ''
                $.each($(this).closest('li').attr('class').split(' '), function (index, value) {
                    if (/\d/.test(value) == true) {
                        menu_object_id = value.replace('menu-item-', '')
                        return
                    }
                })
                if (
                    $(this)
                        .closest('.sno-designer-area-container')
                        .find('.sub-menu-teaser-display-' + menu_object_id).length < 1
                )
                    return
                $(this).closest('li').addClass('sub-menu-teasers')
                $('<li class="menu-ta-wrap"><div class="menu-ta"><div class="menu-ta-inner"></div></div><div class="clear"></div></li>').insertAfter(
                    $(this).find('li').last()
                )
            })
        $(menu)
            .find('ul.menu-with-teasers > li.menu-item-object-category, ul.menu-with-teasers > li.menu-item-object-page')
            .each(function () {
                if ($(this).find('ul').length) return
                if ($(this).hasClass('menu-item-object-page')) {
                    var menu_object_id = ''
                    $.each($(this).attr('class').split(' '), function (index, value) {
                        if (/\d/.test(value) == true) {
                            menu_object_id = value.replace('menu-item-', '')
                            return
                        }
                    })
                    if (
                        $(this)
                            .closest('.sno-designer-area-container')
                            .find('.sub-menu-teaser-display-' + menu_object_id).length < 1
                    )
                        return
                }
                $(this).addClass('sub-menu-teasers')
                $(this).append(
                    '<ul class="sub-menu"><li class="menu-ta-wrap"><div class="menu-ta-full"><div class="menu-ta-inner"></div></div><div class="clear"></div></li></ul>'
                )
            })
    }

    // if menus have too many items in them, collapse the extras into an extra tab under "More"
    function hide_extra_menu_items(menu) {
        var max_width = $(menu).width()
        var total_width = 0
        $(menu)
            .find('ul.sf-menu > li')
            .each(function () {
                total_width += $(this).outerWidth()
                total_width += 4
                if ($(this).find('ul').length) {
                    total_width += 12 // account for drop down arrows
                }
            })

        if (total_width > max_width) {
            $(menu).find('ul.sno-menu-more').show()
            $(menu).find('ul.sno-hac-menu-more').show()
            var menu_ul_id = $(menu).find('ul').first().attr('id')
            var more_button_width = $(menu).find('li.menu-more-item-top').width()
            total_width += more_button_width

            $($(menu).find('ul.sf-menu > li').get().reverse()).each(function () {
                var li_width = $(this).outerWidth()
                $(this).addClass('sub-menu')
                $(this).prependTo($(menu).find('ul.sno-hac-menu-more'))
                total_width -= li_width
                if (total_width + 15 < max_width) return false // the 15 is just an added buffer
            })

            $(menu).find('ul.sno-menu-more').addClass('sf-menu').superfish()
            $(menu)
                .find('.menu-more-item-top')
                .appendTo('#' + menu_ul_id)
        }

        $(menu).css({'overflow-y': 'unset'})

        if ($(window).width() > 800) prepare_menus_with_teasers(menu)
    }

    // hide extra menu items in the more tab on load
    $(document).ready(function () {
        $('.sno-hac-menuwrap, .sno-classic-menuwrap').each(function () {
            if ($('.sno-story-template-fulltop').length) return true;
            if ($('.sno-story-fulltop-container').length) return true;
            if ($('.sno-story-template-split').length) return true;
            hide_extra_menu_items(this)
        })
    })

    // open up search bar when search icon is clicked
    $(document).ready(function () {
        $('body').on('click', '.sno-hac-search-icon', function () {
            $(this).find('i').toggleClass('fa-search fa-times')
            $('.sno-hac-hamburger-menu').hide()
            const hidden = ($('.sno-hac-search-icon-bar-' + $(this).data('id')).is(':hidden')) ? true : false;
            $('.sno-hac-search-icon-bar-' + $(this).data('id')).fadeToggle()
            if (hidden === true) {
                $('.sno-hac-search-icon-bar-' + $(this).data('id')).find('input.hac-search').focus()
            }
        })
    })

    // open up menu when hamburger icon is clicked
    $(document).ready(function () {
        $('body').on('click', '.sno-hac-menu-icon', function () {
            //	$(this).find('i').toggleClass('fa-bars fa-times')
            $('.sno-hac-search-icon-bar').hide()
            var menu = $('.sno-hac-hamburger-menu-' + $(this).data('menu-id'))
            menu.fadeToggle()
            if ($(this).hasClass('sno-hac-menu-side')) {
                restrictFocusToMenu(menu)
            }
            if ($(window).width() > 800 && !$(this).hasClass('sno-hac-menu-side')) {
                hide_extra_menu_items(menu)
            } else {
                $(menu).find('.sf-menu').superfish('destroy')
                $('.sno-side-icons').fadeOut();
                if ($('#wpadminbar').length && $('#wpadminbar').is(':visible')) $(this).closest('.sno-designer-area-container').find('.sno-hac-hamburger-menu').css('top', '32px');
            }
            $(this).attr('aria-expanded', 'true');
        })
    })

    function restrictFocusToMenu(menu) {
        let lastFocusableElement;
        const firstFocusableElement = $(menu).find('.sno-hac-menu-mobile-close');

        function updateFocusableElements() {
            // Update first and last focusable elements
            lastFocusableElement = $(menu).find('li:visible a:visible').last();
        }

        // Initialize focusable elements when the modal opens
        setTimeout(function () {
            updateFocusableElements();
        }, 1000)

        jQuery(menu).on('keydown', function (event) {
            updateFocusableElements();
            const isTabPressed = (event.key === 'Tab' || event.keyCode === 9);
            if (!isTabPressed) {
                return;
            }
            if (event.shiftKey) { // Shift + Tab
                if (document.activeElement === firstFocusableElement[0] || document.activeElement === $(firstFocusableElement[0]).closest('li').get(0)) {
                    lastFocusableElement.focus();
                    event.preventDefault();
                }
            } else { // Tab
                if (document.activeElement === lastFocusableElement[0] || document.activeElement === $(lastFocusableElement[0]).closest('li').get(0)) {
                    firstFocusableElement.focus();
                    event.preventDefault();
                }
            }
        });

    }

    $('.sno-hac-menu-wrap li > a').on('click', function (e) {
        if ($(this).siblings('ul').length) {
            if ($(this).siblings('ul').is(':visible')) {
            } else {
                $(this).siblings('ul').slideDown()
                $(this).addClass('sno-menu-expanded')
                e.preventDefault()
            }
        }
    })

    $('body').on('click', '.sno-hac-menu-mobile-close', function () {
        $(this).closest('.sno-hac-hamburger-menu').fadeOut()
        $('.sno-side-icons').fadeIn();
        $('.sno-hac-menu-icon').attr('aria-expanded', 'false')
        //    $('#wpadminbar').css('z-index', '2000')
    })
})

// news tickers for header area
jQuery(function ($) {
    function marquee(a, b, speed, con_width) {
        var width = b.width()
        if (width < 0) {
            b.hide();
            return;
        }
        var start_pos = con_width
        var end_pos = -width

        function scroll() {
            if (b.position().left <= -width + 1) {
                b.css('left', start_pos)
                scroll()
            } else {
                var min_width = width < con_width ? con_width : width
                time = min_width / speed
                b.animate(
                    {
                        left: -width,
                    },
                    time,
                    'linear',
                    function () {
                        scroll()
                    }
                )
            }
        }

        b.css({
            width: width,
            left: start_pos,
        })
        scroll(a, b)

        // pause on hover
        b.mouseenter(function () {
            b.stop()
            b.clearQueue()
        })
        b.mouseleave(function () {
            scroll(a, b)
        })

        // pause marquee when browser tab isn't visible to prevent excessive animations
        document.addEventListener('visibilitychange', function (ev) {
            if (document.visibilityState == 'hidden') {
                b.stop()
                b.clearQueue()
            } else {
                scroll(a, b)
            }
        })

        // pause marquee when focus is within the parent container
        let focusInMarquee = false;

        function checkFocusInParent(parentDiv) {
            if (parentDiv.contains(document.activeElement)) {
                if (focusInMarquee == false) {
                    const actualParentDiv = $(parentDiv).closest('.simple-marquee-container')[0];
                    $(actualParentDiv).find('.marquee-sibling').attr('tabindex', '0');
                    b.stop();
                    b.clearQueue();
                }
                focusInMarquee = true;
            } else {
                if (focusInMarquee == true) {
                    focusInMarquee = false;
                    const currentFocus = a[0];
                    const currentMarquee = currentFocus.closest('.simple-marquee-container').querySelector('.marquee-sibling');

                    $('.marquee-sibling').focus()
                    marquee(a, b, speed, con_width)
                    focusNextElement(currentMarquee)
                }
            }
        }

        const parentDiv = a[0];
        const parentMarquee = parentDiv.closest('.simple-marquee-container').querySelector('.marquee-content-items');
        document.addEventListener('focusin', function () {
            checkFocusInParent(parentMarquee);
        });

        function focusNextElement(currentDiv) {
            // Get all tabbable elements on the page
            const tabbableElements = Array.from(document.querySelectorAll('a, button, input, textarea, select, [tabindex]:not([tabindex="-1"])'))
                .filter(el => !el.disabled && el.offsetParent !== null);

            // Find the index of the currently focused element
            const currentIndex = tabbableElements.indexOf(currentDiv);

            // Focus the next element if it exists
            if (currentIndex > -1 && currentIndex < tabbableElements.length - 1) {
                tabbableElements[currentIndex + 1].focus();
            }
        }

    }


    $(document).ready(function () {
        $('.simple-marquee-container:visible').each(function () {
            if ($(this).data('activate') == true) {
                if ($(this).find('.marquee-sibling').length) {
                    var marquee_width = $(this).width() - $(this).find('.marquee-sibling').width()
                } else {
                    var marquee_width = $(this).width()
                }
                marquee($(this).find('.marquee'), $(this).find('.marquee-content-items'), $(this).find('.marquee').data('speed'), marquee_width)
            } else {
                var left_padding = $(this).find('.marquee-sibling').outerWidth() + 20
                $(this)
                    .find('.marquee')
                    .css({'padding-left': left_padding + 'px'})
            }
            $(this).find('li').css('opacity', 1)
        })
    })
})

// staff profile adjust vertical text centering if text is too tall for area
jQuery(document).ready(function ($) {
    if ($(window).width() > 600) {
        var staff_pic_height = $('.profile-panel-media img').height()
        if (staff_pic_height) {
            var staff_text_height = $('.profile-textarea-inner').height()
            if (staff_pic_height < staff_text_height) {
                $('.profile-textarea-with-media').removeClass('sno-center-v-outer')
                $('.profile-textarea-inner').removeClass('sno-center-v')
            }
        }
    }
    $('.sno-profile-fade').css({position: 'relative'})
    $('.sno-profile-fade').animate({opacity: 1, position: 'relative'})
})

// make photos and continue links clickable on category tile views
jQuery(document).ready(function () {
    jQuery('body').on('click', '.sno-tile-clickable', function () {
        var link = jQuery(this).find('a.homeheadline').attr('href')
        if (link) {
            window.location = link
        }
    })

    jQuery('body').on('click', '.sno-tile-clickable', function () {
        var photo = jQuery(this).find('a').data('photo-id')
        if (photo) {
            jQuery.ajax({
                url: frontend_ajax_object.ajaxurl,
                type: 'POST',
                data: {
                    action: 'snoloadimage',
                    photo: photo,
                },
                success: function (results) {
                    jQuery('.remodal-inner-container').replaceWith(results)
                    sno_slideshow_open = 'yes'
                    var inst = jQuery('[data-remodal-id=modal-photo]').remodal()
                    inst.open()
                    scalephoto()
                },
            })
        }
    })
})

// building the staggered display of tiles for the category view pages
function place_tiles() {
    if (jQuery(window).width() < 980) {
        jQuery('.catpage-tiles-column.column-3').remove()
        jQuery('.catpage-tiles-column.column-2').remove()
    }
    if (jQuery(window).width() < 600) {
        jQuery('.catpage-tiles-column.column-1').remove()
    }
    jQuery('.sno-tile-hidden').each(function () {
        var shortest = [].reduce.call(jQuery('.catpage-tiles-column'), function (sml, cur) {
            return jQuery(sml).height() < jQuery(cur).height() ? sml : cur
        })
        jQuery(this).removeClass('sno-tile-hidden').hide().appendTo(shortest).fadeIn()
    })
}

jQuery(window).load(function () {
    place_tiles()
})

// make sure that all story cards on the category tile view have the same height to create a nice, even display

function resize_tiles() {
    if (jQuery(window).width() > 600) {
        var height = 0
        var tallest = 0
        var set_height = jQuery('.sno-tile-resized').last().height() != null ? jQuery('.sno-tile-resized').last().height() : null
        jQuery('.catlist-tile').each(function () {
            if (!jQuery(this).hasClass('sno-tile-resized')) {
                height = jQuery(this).height()
                tallest = height > tallest ? height : tallest
                if (set_height != null && tallest < set_height) tallest = set_height
            }
        })
        if (jQuery('#staffpage').length) {
            if (tallest > 950) tallest = 950 // preventing runaway heights just in case someone adds something stupid
        } else {
            if (tallest > 750) tallest = 750 // preventing runaway heights just in case someone adds something stupid
        }
        jQuery('.catlist-tile').each(function () {
            if (!jQuery(this).hasClass('sno-tile-resized')) {
                jQuery(this).find('.catlist-tile-inner').height(tallest)
                if (jQuery(this).find('.catlist-tile-textarea').length) jQuery(this).find('.catlist-tile-textarea').addClass('sno-center-v-list')
                jQuery(this).addClass('sno-tile-resized')
            }
        })
    }
}

jQuery(window).load(function () {
    resize_tiles()
})

// force fill "contain" photo photos that are close to filling frame on category pages
function fill_photo() {
    jQuery('.catlist-panel-media img.unscaled').each(function () {
        jQuery(this).removeClass('unscaled')
        var image_ratio = jQuery(this).data('ratio')
        var width = jQuery(this).closest('.catlist-panel-media').width()
        var height = jQuery(this).closest('.catlist-panel-media').height()
        if (height != 0) {
            var area_ratio = (height / width).toFixed(2)
            if (Math.abs(image_ratio - area_ratio) < 0.15) jQuery(this).css({'object-fit': 'cover'})
        }
    })
    jQuery('.catlist-tile img.unscaled').each(function () {
        jQuery(this).removeClass('unscaled')
        var image_ratio = jQuery(this).data('ratio')
        var width = jQuery(this).closest('.catlist-tile-media-photo').width()
        var height = jQuery(this).closest('.catlist-tile-media-photo').height()
        if (height != 0) {
            var area_ratio = (height / width).toFixed(2)
            if (Math.abs(image_ratio - area_ratio) < 0.15) jQuery(this).css({'object-fit': 'cover'})
        }
    })
}

jQuery(document).ready(function ($) {
    fill_photo()
})

// infinite scroll for category pages
jQuery(document).ready(function ($) {
    jQuery('body').on('click', '.sno-infinite-scroll-button-active', function () {
        event.preventDefault()
        var paged = jQuery(this).data('paged') == 0 ? 1 : jQuery(this).data('paged')
        var category = jQuery(this).data('category')
        var tag = jQuery(this).data('tag')
        var taxonomy = jQuery(this).data('taxonomy')
        var template = jQuery(this).data('template')
        var search = jQuery(this).data('search')
        var term = jQuery(this).data('term')
        var year = jQuery(this).data('year')
        var month = jQuery(this).data('month')

        var find_rendered = []
        $('.profile-rendered').each(function () {
            find_rendered.push($(this).data('rendered'))
        })
        var rendered = find_rendered.join(',')

        jQuery('.sno-infinite-scroll-button').text($('#content').data('loading'))

        jQuery.ajax({
            url: frontend_ajax_object.ajaxurl,
            type: 'POST',
            data: {
                action: 'snoinfinite',
                category: category,
                tag: tag,
                paged: paged,
                template: template,
                taxonomy: taxonomy,
                search: search,
                term: term,
                year: year,
                month: month,
                rendered: rendered,
            },
            success: function (results) {
                jQuery('.sno-infinite-scroll-button').data('paged', paged + 1)
                jQuery(results).insertBefore('.sno-infinite-scroll-insertion')
                jQuery('.profile-keepalive').remove()
                jQuery('.sno-infinite-scroll-button').addClass('sno-infinite-scroll-button-active')
                place_tiles()
                fill_photo()
                resize_tiles()
                if (results == '') {
                    jQuery('.sno-infinite-scroll-button').text($('#content').data('loaded'))
                    jQuery('.sno-infinite-scroll-button').removeClass('sno-infinite-scroll-button-active')
                } else {
                    jQuery('.sno-infinite-scroll-button').text($('#content').data('load'))
                }
            },
        })
    })
})

jQuery(window).on('scroll', function () {
    var scrollHeight = jQuery(document).height()
    var scrollPosition = jQuery(window).height() + jQuery(window).scrollTop()
    if ((scrollHeight - 300 >= scrollPosition) / scrollHeight == 0) {
        if (jQuery('.sno-infinite-scroll-button').hasClass('sno-infinite-scroll-button-active')) {
            jQuery('.sno-infinite-scroll-button-active').click()
            jQuery('.sno-infinite-scroll-button').removeClass('sno-infinite-scroll-button-active')
        }
    }
})

// make photos and continue links clickable on category views
jQuery(document).ready(function () {
    jQuery('.catlist-panel .continue, .catlist-panel img, a.catlist-photooverlay').click(function () {
        var link = jQuery(this).closest('.catlist-panel').find('a.homeheadline').attr('href')
        if (link) {
            window.location = link
        }

        var photo = jQuery(this).closest('.catlist-panel').find('a').data('photo-id')
        if (photo) {
            jQuery.ajax({
                url: frontend_ajax_object.ajaxurl,
                type: 'POST',
                data: {
                    action: 'snoloadimage',
                    photo: photo,
                },
                success: function (results) {
                    jQuery('.remodal-inner-container').replaceWith(results)
                    sno_slideshow_open = 'yes'
                    var inst = jQuery('[data-remodal-id=modal-photo]').remodal()
                    inst.open()
                    scalephoto()
                },
            })
        }
    })
})

// when text is vertically centered on category list view, if the text area is taller than the photo, it won't look good. Expand the height of the text area to match its actual height
jQuery(window).load(function () {
    jQuery('.catlist-textarea-with-media').each(function () {
        var photo_height = jQuery(this).closest('.catlist-panel').find('.catlist-panel-media').height()
        var text_height = jQuery(this).height()
        if (text_height > photo_height) {
            jQuery(this).css({
                position: 'unset',
                transform: 'unset',
                'padding-top': 0,
                'margin-right': '-15px',
            })
        }
    })
})
// do it again on ready just to be safe
jQuery(document).ready(function () {
    jQuery('.catlist-textarea-with-media').each(function () {
        var photo_height = jQuery(this).closest('.catlist-panel').find('.catlist-panel-media').height()
        var text_height = jQuery(this).height()
        if (text_height > photo_height) {
            jQuery(this).css({position: 'unset', transform: 'unset'})
        }
    })
})

// make menu teaser photos clickable
jQuery(document).ready(function () {
    jQuery('body').on('click', '.sno-story-card-photo-wrap', function () {
        if (jQuery(this).closest('.sno-menu-card').find('a').length) {
            window.location = jQuery(this).closest('.sno-menu-card').find('a').attr('href')
        }
    })
})

// make full tag clickable
jQuery(document).ready(function () {
    jQuery('li.blockstag').click(function () {
        if (jQuery(this).find('a').length) {
            window.location = jQuery(this).find('a').attr('href')
        }
    })
})

// story list widget
jQuery(document).ready(function () {
    jQuery('.sno-story-card, .dual-format-card').click(function () {
        if (jQuery(this).find('a.homeheadline').length) {
            window.location = jQuery(this).find('a.homeheadline').attr('href')
        }
    })
})

// make sure that all story list cards in a horizontal row have the same height to create a nice, even display

jQuery(window).load(function () {
    jQuery('.list-horizontal').each(function () {
        var height = 0
        var tallest = 0
        jQuery(this)
            .find('.sno-story-card')
            .each(function () {
                height = jQuery(this).height()
                tallest = height > tallest ? height : tallest
            })
        if (jQuery(this).closest('.sno-story-list-widget').find('.story-widget-secondary').length) {
            var secondary_height = jQuery(this).closest('.sno-story-list-widget').find('.story-widget-secondary').height()
            tallest = secondary_height > tallest ? secondary_height : tallest
        }
        jQuery(this).find('.sno-story-card').height(tallest)
    })
})

// parallax widget
jQuery(document).ready(function () {
    jQuery('.bcg').click(function () {
        window.location = jQuery(this).find('a').attr('href')
    })

    jQuery('.text-parallax').click(function () {
        window.location = jQuery(this).find('a').attr('href')
    })

    jQuery('.text-overlay-parallax-mobile').each(function () {
        var height = jQuery(this).height()
        var photoHeight = jQuery(this).closest('.parallax-mobile-widget-tile').find('img.parallax-mobile-image').height()
        var new_padding = Math.floor((photoHeight - height) / 2)
        jQuery(this).css('padding-top', new_padding)
    })
})

jQuery(window).load(function () {
    $body = jQuery('.parallaxcontainer')
    if (jQuery('.parallaxcontainer').is('.instantiate-parallax')) {
        var s = skrollr.init({
            forceHeight: false,
        })
        jQuery('.parallaxcontainer').css('height', 'auto')
        jQuery('.parallaxcontainer section').fadeIn(2000)
        s.refresh(jQuery('.homeSlide'))
    }
})

// make sure that all trending stories cards in a horizontal row have the same height for photo and text to create a nice, even display

jQuery(window).load(function () {
    jQuery('.sno-widget-card-wrapper.trending-horizontal').each(function () {
        var height = 0
        var tallest = 0

        jQuery(this)
            .find('.sno-trending-card')
            .each(function () {
                height = jQuery(this).height()
                tallest = height > tallest ? height : tallest
            })
        jQuery(this).find('.sno-trending-card').height(tallest)
    })
})

// make sure that all trending stories cards are the same height

jQuery(window).load(function () {
    jQuery('.sno-widget-trending-wrapper.trending-horizontal').each(function () {
        var card_height = 0
        var tallest_card = 0

        jQuery(this)
            .find('.trending-row-wrap')
            .each(function () {
                card_height = jQuery(this).height()
                tallest_card = card_height > tallest_card ? card_height : tallest_card
            })
        jQuery(this).find('.trending-row-wrap').height(tallest_card)
    })
})

// make sure that all cards in a row have the same height for photo and text to create a nice, even display

jQuery(window).load(function () {
    jQuery('.sno-widget-card-wrapper.sno-card-row').each(function () {
        var title_height = 0
        var teaser_height = 0
        var tallest_title = 0
        var tallest_teaser = 0

        jQuery(this)
            .find('.sno-content-card')
            .each(function () {
                title_height = jQuery(this).find('.sno-profile-card-header-wrap').height()
                tallest_title = title_height > tallest_title ? title_height : tallest_title
                teaser_height = jQuery(this).find('.sno-profile-card-teaser').height()
                tallest_teaser = teaser_height > tallest_teaser ? teaser_height : tallest_teaser
            })
        jQuery(this).find('.sno-profile-card-header-wrap').height(tallest_title)
        jQuery(this).find('.sno-profile-card-teaser').height(tallest_teaser)
    })
})

// adjust the height of teasers so that text doesn't get cut off at the bottom of the widget

jQuery(document).ready(function () {
    jQuery('.sno-widget-card-wrapper.sno-card-row, .sno-widget-card-wrapper.sno-vertical-stack').each(function () {
        jQuery(this)
            .find('.sno-content-card.sno-profile-small-photo')
            .each(function () {
                var name_height = jQuery(this).find('.sno-profile-name').height()
                var title_height = jQuery(this).find('.sno-profile-title').height()
                var teaser_height = jQuery(this).find('p').height()
                var photo_height = jQuery(this).find('.sno-profile-card-image').height()
                var line_height = parseInt(jQuery(this).find('.sno-card-teaser p').css('line-height'))
                var font_size = parseInt(jQuery(this).find('.sno-card-teaser p').css('font-size'))
                var card_bottom_padding = parseInt(jQuery(this).css('padding-bottom'))

                var buffer = (line_height - font_size) / 2

                if (photo_height != null) {
                    var text_height_area_max = photo_height - name_height - title_height - 10 + card_bottom_padding
                    while (teaser_height >= text_height_area_max) teaser_height -= line_height
                    teaser_height += buffer
                }
            })
        if (typeof teaser_height != 'undefined' && teaser_height !== null)
            jQuery(this)
                .find('.sno-profile-card-teaser')
                .css({height: teaser_height + 'px', overflow: 'hidden'})
    })
})

jQuery(document).ready(function () {
    // sports score hover effect for links
    jQuery('body').on('mouseenter', 'a .scorewrap.sc_horizontal', function () {
        jQuery(this).addClass('sc_score_link')
    })
    jQuery('body').on('mouseleave', 'a .scorewrap.sc_horizontal', function () {
        jQuery(this).removeClass('sc_score_link')
    })

    jQuery('body').on('mouseenter', 'a .scorewrap.sc_vertical', function () {
        jQuery(this).addClass('sc_score_link_vertical')
    })
    jQuery('body').on('mouseleave', 'a .scorewrap.sc_vertical', function () {
        jQuery(this).removeClass('sc_score_link_vertical')
    })

    // schedule/results widgets -- show dropdown choice for individual sports
    jQuery('body').on('click', '.scheduleheader', function () {
        jQuery(this).closest('.widgetwrap').find('.widget-sports-list').slideToggle()
        jQuery(this).closest('.widgetwrap').find('.sno-sports-selector-icon').toggleClass('dashicons-arrow-down dashicons-arrow-up')
    })

    // make table cells clickble on sports tables
    jQuery('table.schedulewidget td').click(function () {
        var href = jQuery(this).find('a').attr('href')
        if (href) {
            window.location = href
        }
    })
})

jQuery(window).load(function () {

    // sports score carousel widget

    jQuery(function ($) {
        $('.weather-widget-carousel').each(function () {
            var transition_speed = $(this).data('transition-speed')
            var slide_duration = $(this).data('slide-duration')
            var margin_width = $(this).data('margin-width')
            var item_width = $(this).data('item-width')
            var move_number = $(this).data('move-number')
            var navigation_buttons = $(this).data('navigation-buttons')

            $(this).flexslider({
                animationSpeed: transition_speed,
                slideshowSpeed: slide_duration,
                slideshow: false,
                animation: 'slide',
                direction: 'horizontal',
                directionNav: true,
                animationLoop: true,
                controlNav: false,
                minItems: 1,
                move: 12,
                maxItems: 15,
                itemWidth: item_width,
                itemMargin: margin_width,
            })

            $(this).find('.flex-viewport').css({height: '200px!important'})
        })
    })


    // carousel widget -- instantiate flexslider for all carousel widgets

    jQuery(function ($) {
        $('.carousel-widget .carouselslider').each(function () {
            var transition_speed = $(this).data('transition-speed')
            var auto_scroll = $(this).data('auto-scroll')
            var transition_style = $(this).data('transition-style')
            var navigation_buttons = $(this).data('navigation-buttons')
            var width_adjustment = $(this).data('width-adjustment')
            var auto_scroll_speed = $(this).data('auto-scroll-speed')
            var display_number = $(this).data('display-number')
            var move_number = $(this).data('move-number')
            var margin_width = $(this).data('margin-width')
            var item_width = $(this).data('item-width')
            var show_thumbnails = $(this).data('show-thumbnails')
            var full_screen = $(this).data('full-screen')
            var thumbnail_width = $(this).data('thumbnail-width')
            var thumbnail_margin = $(this).data('thumbnail-margin')
            var container = $(this);

            if (full_screen == 'widgetfullscreen' && display_number != '1') {
                item_width = (jQuery(window).width() - width_adjustment) / display_number
            } else if (full_screen == 'widgetfullscreen') {
                item_width = jQuery(window).width()
            } else {
                item_width = ($(this).closest('.carouselslider').width() - width_adjustment) / display_number
            }
            $(this).find('li.carousel-widget-slide').width(item_width)

            if (show_thumbnails == 'on') {
                jQuery(this)
                    .closest('.carousel-widget')
                    .find('.thumbnailslider')
                    .flexslider({
                        animation: 'slide',
                        customDirectionNav: jQuery(this).closest('.carousel-widget').find('.thumbnailslider .custom-navigation span'),
                        controlNav: false,
                        directionNav: true,
                        animationLoop: true,
                        slideshow: false,
                        itemWidth: thumbnail_width,
                        itemMargin: thumbnail_margin,
                        touch: true,
                        asNavFor: $(this).closest('.carousel-widget').find('.carouselslider'),
                    })
            }

            $carousel = $(this).flexslider({
                animationSpeed: transition_speed,
                animationLoop: true,
                customDirectionNav: jQuery(this).find('.custom-navigation span'),
                controlNav: navigation_buttons,
                smoothHeight: false,
                slideshowSpeed: auto_scroll_speed,
                slideshow: auto_scroll,
                animation: transition_style,
                sync: $(this).closest('.carousel-widget').find('.thumbnailslider'),
                itemWidth: item_width,
                itemMargin: margin_width,
                minItems: 1,
                move: move_number,
                pauseOnAction: true,
                maxItems: 5,
                after: function () {
                    restrictFocusToVisibleSlides(container);
                }
            })
            setTimeout(function () {
                restrictFocusToVisibleSlides(container);
            }, 1000);
            var height_method = $(this).data('height-method')
            var height_ratio = $(this).data('height-ratio')

            var carouselWidth = jQuery(this).width()
            var carouselHeight = Math.floor((jQuery(this).width() * height_ratio) / 100)

            if (height_method == 'Ratio') jQuery(this).find('ul.slides li').css('height', carouselHeight)


            const $navigationButton = $(this).find('.custom-navigation');
            $navigationButton.on('keydown', function (event) {
                if (event.key === 'Enter' || event.keyCode === 13) {
                    const $slideshowRight = $(this).find('.sno_slideshow_right span');
                    if ($slideshowRight.length) {
                        $slideshowRight.trigger('click');
                    }
                    const $slideshowLeft = $(this).find('.sno_slideshow_left span');
                    if ($slideshowLeft.length) {
                        $slideshowLeft.trigger('click');
                    }
                }
            });
            $carousel.on('focusin', function () {
                $carousel.flexslider("pause");
            });

        });

        $('.infobox-carousel').each(function () {
            var infobox_id = $(this).closest('.sno-infobox').data('id');
            var container = $(this);
            $(this).flexslider({
                animation: "slide",
                animationLoop: false,
                controlNav: true,
                customDirectionNav: $('.sno-infobox-' + infobox_id + ' .custom-navigation span'),
                slideshow: false,
                itemMargin: 0,
                touch: true,
                itemWidth: 375,
                minItems: 1,
                move: 1,
                maxItems: 1,
                before: function () {
                    $('button.infobox-nav-button').removeAttr('tabindex');
                },
                after: function () {
                    restrictFocusToVisibleSlides(container);
                    $('.flex-disabled').closest('button').attr('tabindex', '-1');
                }
            });
            setTimeout(function () {
                restrictFocusToVisibleSlides(container)
                $('.flex-disabled').closest('button').attr('tabindex', '-1');
            }, 1000);


        });

        $('body').on('keydown', '.infobox-nav-button', function (event) {
            event.stopPropagation();
            if (event.key === 'Enter' || event.keyCode === 13) {
                event.preventDefault();
                const $slideshowRight = $(this).find('span.flex-prev');
                if ($slideshowRight.length) {
                    $slideshowRight.trigger('click');
                }
                const $slideshowLeft = $(this).find('span.flex-next');
                if ($slideshowLeft.length) {
                    $slideshowLeft.trigger('click');
                }
            }
        });

        $('.infobox-carousel .flex-control-paging').attr('aria-hidden', 'true');
        $('.infobox-carousel .flex-control-paging a').attr('tabindex', '-1');

        jQuery(function ($) {
            $('.sports-widget-carousel').each(function () {
                var direction = $(this).data('direction')
                var transition_speed = $(this).data('transition-speed')
                var slide_duration = $(this).data('slide-duration')
                var margin_width = $(this).data('margin-width')
                var item_width = $(this).data('item-width')
                var move_number = $(this).data('move-number')
                var container = $(this);

                if (direction == 'vertical') {
                    item_width = null
                    margin_width = null
                }

                var carousel = $(this)
                $(this).flexslider({
                    animationSpeed: transition_speed,
                    slideshowSpeed: slide_duration,
                    slideshow: true,
                    animation: 'slide',
                    direction: direction,
                    directionNav: false,
                    animationLoop: true,
                    controlNav: false,
                    pausePlay: true,
                    minItems: 1,
                    move: 1,
                    maxItems: 5,
                    itemWidth: item_width,
                    itemMargin: margin_width,
                    after: function () {
                        restrictFocusToVisibleSlides(container);
                    }
                })
                setTimeout(function () {
                    restrictFocusToVisibleSlides(container);
                }, 1000);

                $(this).find('.flex-viewport').css({height: '200px!important'})
                $(this).find('.flex-pauseplay').prependTo($(this));
            })

            $('body').on('focus', '.sports-widget-carousel', function () {
                $(this).addClass('activate-tab-controls');
            })
            // $('body').on('focus', '.flex-pauseplay', function(e) {
            //     e.preventDefault();
            // })

        })


        // functions for related stories in bottom drawer on story page
        $('body').on('click', '.bottom-drawer-header', function () {
            $(this).find('.bottom-drawer-toggle').toggleClass('fa-angle-up fa-angle-down');
            if ($('.related-term-container-active:visible').length) {
                $(this).closest('.related-bottom-drawer').removeClass('hide-shadow');
                $(this).closest('.related-bottom-drawer').find('.related-term-container').slideUp();
                $('.bottom-drawer-background').removeClass('bottom-drawer-background-active');
                $(this).find('.bds-arrows').fadeOut();
                $(this).find('.bds-arrow').attr('tabindex', '-1');
                $(this).find('.bottom-drawer-toggle').attr('aria-expanded', 'false');
            } else {
                if ($('.related-term-container-active').length) {
                    $(this).closest('.related-bottom-drawer').find('.related-term-container-active').slideDown();
                } else {
                    $(this).closest('.related-bottom-drawer').find('.related-term-container').first().slideDown().addClass('related-term-container-active');
                }
                $(this).closest('.related-bottom-drawer').addClass('hide-shadow');
                $('.bottom-drawer-background').addClass('bottom-drawer-background-active');
                $(this).find('.bds-arrows').fadeIn();
                $(this).find('.bds-arrow').attr('tabindex', '0');
                restrictFocusToVisibleList($(this).closest('.related-bottom-drawer'));
                $(this).find('.bottom-drawer-toggle').attr('aria-expanded', 'true');
            }
        });

        function restrictFocusToVisibleList(container) {
            $('.related-term-container a').attr('tabindex', '-1');
            $('.related-term-container-active a').attr('tabindex', '0');
            const modal = jQuery(container);
            const focusableElementsSelector = '[tabindex="0"]';
            let firstFocusableElement, lastFocusableElement;

            function updateFocusableElements() {
                // Update first and last focusable elements
                const focusableElements = jQuery(modal).find(focusableElementsSelector);
                firstFocusableElement = focusableElements[0];
                lastFocusableElement = focusableElements[focusableElements.length - 1];
            }

            // Initialize focusable elements when the modal opens
            setTimeout(function () {
                updateFocusableElements();
            }, 1000)

            jQuery(modal).on('keydown', function (event) {
                const isTabPressed = (event.key === 'Tab' || event.keyCode === 9);
                if (!isTabPressed) {
                    return;
                }

                if (event.shiftKey) { // Shift + Tab
                    if (document.activeElement === firstFocusableElement) {
                        lastFocusableElement.focus();
                        event.preventDefault();
                    }
                } else { // Tab
                    if (document.activeElement === lastFocusableElement) {
                        firstFocusableElement.focus();
                        event.preventDefault();
                    }
                }
            });
        }

        $('body').on('keydown', '.bds-arrow, .bottom-drawer-toggl, .sno-hac-menu-mobile-close, .infobox-toggle, .sno-sports-selector-icon, .bottom-drawer-toggle, .live-update-share-link, .sno-fill', function (event) {
            if (event.key === 'Enter' || event.keyCode === 13) {
                $(this).trigger('click');
            }
        });
        $('body').on('keydown', '.grid-widget-tile', function (event) {
            if (event.key === 'Enter' || event.keyCode === 13) {
                $(this).find('a').trigger('click');
            }
        });

        $('body').on('click', '.bds-arrow', function (e) {
            e.stopPropagation();
            if (!$(this).hasClass('bds-arrow-active')) return false;

            // mark the next slide
            if ($(this).hasClass('bds-arrow-right')) {
                if ($('.related-term-container-active').next('.related-term-container').length) {
                    $('.related-term-container-active').next('.related-term-container').addClass('related-term-container-next');
                }
            }
            if ($(this).hasClass('bds-arrow-left')) {
                if ($('.related-term-container-active').prev('.related-term-container').length) {
                    $('.related-term-container-active').prev('.related-term-container').addClass('related-term-container-next');
                }
            }
            // move the slides
            $('.related-term-container-active').slideUp().removeClass('related-term-container-active');
            $('.related-term-container-next').slideDown().addClass('related-term-container-active').removeClass('related-term-container-next');

            // adjust the arrows
            if ($('.related-term-container-active').next('.related-term-container').length) {
                $('.bds-arrow-right').addClass('bds-arrow-active')
            } else {
                $('.bds-arrow-right').removeClass('bds-arrow-active')
            }
            if ($('.related-term-container-active').prev('.related-term-container').length) {
                $('.bds-arrow-left').addClass('bds-arrow-active')
            } else {
                $('.bds-arrow-left').removeClass('bds-arrow-active')
            }

        })

        function restrictFocusToVisibleSlides(container) {
            const slides = $(container).find('.carousel-widget-slide, .infobox-list-item, .header-carousel-slide');
            let viewport = $(container).find('.flex-viewport').get(0); // Convert to a native DOM element
            if (viewport === undefined) return

            slides.each(function () {
                const slide = $(this); // Convert the current slide to a jQuery object
                const rect = slide[0].getBoundingClientRect(); // Get the DOM element from jQuery object
                const viewportRect = viewport.getBoundingClientRect();

                // Check if the slide is at least partially visible within the viewport
                const isVisible = rect.right > viewportRect.left &&
                    rect.left < viewportRect.right &&
                    rect.bottom > viewportRect.top &&
                    rect.top < viewportRect.bottom;

                if (isVisible) {
                    slide.addClass('visible-slide');
                    slide.find('a').removeAttr('tabindex');
                } else {
                    slide.removeClass('visible-slide');
                    slide.find('a').attr('tabindex', '-1')
                }
            });
        }

    })
})

function scalephoto() {
    jQuery('.slideshow-photo-container').each(function () {
        photo_w = jQuery(this).find('img').attr('data-width')
        photo_h = jQuery(this).find('img').attr('data-height')
        if (photo_h > 0) {
            photo_ratio = photo_w / photo_h
        } else {
            photo_ratio = 2
        }
        area_w = jQuery(this).width()
        area_h = jQuery(this).height()
        if (area_h > 0) {
            area_ratio = area_w / area_h
        } else {
            area_ratio = 2
        }
        photo_ratio = photo_ratio.toFixed(2)
        area_ratio = area_ratio.toFixed(2)
        ratio_diff = Math.abs(area_ratio - photo_ratio).toFixed(2)
        if (ratio_diff < 0.3 && photo_w > area_w * 0.7 && photo_h > area_h * 0.7) {
            jQuery(this).find('img').addClass('forcefill')
        } else {
            jQuery(this).find('img').removeClass('forcefill')
        }
    })
}

jQuery(function () {
    window.onresize = function () {
        scalephoto()
        scalephotos()
    }
})

function scalephotos() {
    jQuery('#sfi-slideshow ul.slides li.storyslide').each(function () {
        photo_w = jQuery(this).find('img').attr('data-width')
        photo_h = jQuery(this).find('img').attr('data-height')
        if (photo_h > 0) {
            photo_ratio = photo_w / photo_h
        } else {
            photo_ratio = 2
        }
        area_w = jQuery(this).find('.sfi-photo-wrap').width()
        area_h = jQuery(this).find('.sfi-photo-wrap').height()
        if (area_h > 0) {
            area_ratio = area_w / area_h
        } else {
            area_ratio = 2
        }
        photo_ratio = photo_ratio.toFixed(2)
        area_ratio = area_ratio.toFixed(2)
        ratio_diff = Math.abs(area_ratio - photo_ratio).toFixed(2)
        if (ratio_diff < 0.3 && photo_w > area_w * 0.7 && photo_h > area_h * 0.7) {
            jQuery(this).find('img').addClass('forcefill')
        } else {
            jQuery(this).find('img').removeClass('forcefill')
        }
    })
}

jQuery(document).ready(function () {
    // functions for closing remodal windows on scroll down

    var sno_slideshow_open = 'no';
    var photo_overlay_last_focus = '';
    jQuery('body').keypress(function (e) {
        if (e.which == 27 || e.which == 0) {
            sno_slideshow_open = 'no'
        }
    })

    jQuery('html').on('wheel', function (event) {
        var delta = {
            y: event.originalEvent.deltaY,
        }

        if (delta.y > 20 && sno_slideshow_open == 'yes') {
            jQuery('button.remodal-close').trigger('click')
            sno_slideshow_open = 'no'
        }
    })

    // for images set as the featured image

    jQuery('body').on('click', '.photooverlay, .photo-enlarge', function () {
        var photo = jQuery(this).data('photo-id')
        var story = jQuery(this).data('story-id')
        var clicked = jQuery(this);
        var windowWidth = jQuery(window).width();
        photo_overlay_last_focus = jQuery(this);
        jQuery.ajax({
            url: frontend_ajax_object.ajaxurl,
            type: 'POST',
            data: {
                action: 'snoloadimage',
                photo: photo,
                story: story,
                width: windowWidth
            },
            success: function (results) {
                jQuery('.remodal-inner-container').replaceWith(results)
                sno_slideshow_open = 'yes'
                var inst = jQuery('[data-remodal-id=modal-photo]').remodal()
                jQuery('[data-remodal-id=modal-photo]').attr('aria-labelledby', 'modal-title-' + photo)
                inst.open()
                scalephoto()
                jQuery(clicked).closest('.photowrap').find('a').attr('aria-expanded', 'true')

                // controlling focus and tabbing in modal
                const modal = jQuery('[data-remodal-id="modal-photo"]');
                const focusableElements = 'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])';
                let firstFocusableElement, lastFocusableElement, previouslyFocusedElement;
                firstFocusableElement = jQuery(modal).find(focusableElements)[0];
                lastFocusableElement = jQuery(modal).find(focusableElements)[jQuery(modal).find(focusableElements).length - 1];
                firstFocusableElement.focus();

                jQuery(modal).on('keydown', function (event) {
                    const isTabPressed = (event.key === 'Tab' || event.keyCode === 9);
                    if (!isTabPressed) {
                        return;
                    }
                    if (event.shiftKey) { // Shift + Tab
                        if (document.activeElement === firstFocusableElement) {
                            lastFocusableElement.focus();
                            event.preventDefault();
                        }
                    } else { // Tab
                        if (document.activeElement === lastFocusableElement) {
                            firstFocusableElement.focus();
                            event.preventDefault();
                        }
                    }
                })
            },
        })
    })

    function link_is_external(link_element) {
        return link_element.host !== window.location.host
    }

    // for images inserted into the body of the story
    jQuery(document).ready(function ($) {
        $('.storycontent a, .sno-story-body a').each(function () {
            if ($(this).find('img').length) {
                if (link_is_external(this)) {
                    return true
                }
                $(this).attr('aria-haspopup', 'dialog');
                $(this).attr('aria-expanded', 'false');
                $(this).attr('aria-label', 'View full size photo');
            }
        })
    })
    jQuery('body').on('click', '.storycontent a, .sno-story-body a', function (e) {
        if (jQuery(this).find('img').length) {
            // test if the image is linked to something on current site vs. being linked to external site.  If linked externally, return true
            if (link_is_external(this)) {
                return true
            }


            var clicked = jQuery(this);
            photo_overlay_last_focus = jQuery(this);

            var img_link = jQuery(this).attr('href')

            if (
                img_link.indexOf('.jpg') === -1 &&
                img_link.indexOf('.jpeg') === -1 &&
                img_link.indexOf('.png') === -1 &&
                img_link.indexOf('.webp') === -1 &&
                img_link.indexOf('attachment') === -1
            )
                return true

            var image_id = jQuery(this)
                .find('img')
                .attr('class')
                .match(/[\w-]*wp-image-[\w-]*/g)
                .toString()
                .replace('wp-image-', '')

            var post_id = jQuery(this).closest('div.snopostid').attr('id').toString().replace('snopostid-', '')
            var windowWidth = jQuery(window).width();

            jQuery.ajax({
                url: frontend_ajax_object.ajaxurl,
                type: 'POST',
                data: {
                    action: 'snoloadimage',
                    photo: image_id,
                    story: post_id,
                    width: windowWidth
                },
                success: function (results) {
                    jQuery('.remodal-inner-container').replaceWith(results)
                    sno_slideshow_open = 'yes'
                    jQuery(clicked).attr('aria-expanded', 'true')

                    var inst = jQuery('[data-remodal-id=modal-photo]').remodal()
                    inst.open()
                    scalephoto()

                    // controlling focus and tabbing in modal
                    const modal = jQuery('[data-remodal-id="modal-photo"]');
                    const focusableElementsSelector = 'button, a:not([tabindex="-1"])';
                    let firstFocusableElement, lastFocusableElement;

                    const focusableElements = jQuery(modal).find(focusableElementsSelector);
                    firstFocusableElement = focusableElements[0];
                    lastFocusableElement = focusableElements[focusableElements.length - 1];

                    // Initialize focusable elements when the modal opens
                    setTimeout(function () {
                        firstFocusableElement.focus();
                    }, 1000)

                    jQuery(modal).on('keydown', function (event) {
                        const isTabPressed = (event.key === 'Tab' || event.keyCode === 9);
                        if (!isTabPressed) {
                            return;
                        }

                        if (event.shiftKey) { // Shift + Tab
                            if (document.activeElement === firstFocusableElement) {
                                lastFocusableElement.focus();
                                event.preventDefault();
                            }
                        } else { // Tab
                            if (document.activeElement === lastFocusableElement) {
                                firstFocusableElement.focus();
                                event.preventDefault();
                            }
                        }
                    });

                },
            })

            return false
        }
    })

    // for SNO slideshows

    jQuery('.sfiphotowrap .slideshow-enlarge').click(function () {
        jQuery(this).closest('.sfiphotowrap').trigger('click')
    })
    jQuery(document).ready(function ($) {
        $('body').on('click', '.sfiphotowrap', function (event) {
            event.preventDefault();
            photo_overlay_last_focus = jQuery(this);
            var image = jQuery(this).attr('data-photo-id')
            var storyid = jQuery(this).attr('data-story-id')
            var widget = jQuery(this).attr('data-widget')
            var photo_ids = jQuery(this).attr('data-photo-ids')
            var clicked_image = jQuery(this).find('li.flex-active-slide .inline-photo-wrap').data('image')
            var windowWidth = jQuery(window).width();
            var clicked = jQuery(this);
            if (clicked_image == undefined) var clicked_image = image
            jQuery(this).find('a.modal-photo').attr('aria-expanded', 'true');

            sno_slideshow_open = 'yes'
            jQuery('.remodal-inner-container').empty()
            if (photo_ids == undefined) {
                photo_ids = '';
                jQuery(this).closest('.widget-inline-gallery').find('.widget-inline-gallery-thumb').each(function () {
                    if (photo_ids) photo_ids += ',';
                    photo_ids += jQuery(this).data('photo-id')
                });
            }
            var inst = jQuery('[data-remodal-id=modal-photo]').remodal()
            inst.open()
            //jQuery('[data-remodal-id=modal-photo]').attr('aria-labelledby', 'modal-title-' + photo)

            jQuery.ajax({
                url: frontend_ajax_object.ajaxurl,
                type: 'POST',
                data: {
                    action: 'getslideshow',
                    storyid: storyid,
                    image: clicked_image,
                    photoids: photo_ids,
                    width: windowWidth,
                    widget: widget,
                },
                success: function (results) {
                    jQuery('.remodal-inner-container').replaceWith(results)


                    jQuery(clicked).closest('.photowrap').find('a').attr('aria-expanded', 'true')

                    // controlling focus and tabbing in modal
                    const modal = jQuery('[data-remodal-id="modal-photo"]');
                    const focusableElementsSelector = 'button, a:not([tabindex="-1"])';
                    let firstFocusableElement, lastFocusableElement;

                    function updateFocusableElements() {
                        // Reset tabindex for all links in inactive slides
                        $('.remodal-is-opened').find('li.storyslide:not(.flex-active-slide)').find('a').attr('tabindex', '-1');

                        // Update first and last focusable elements
                        const focusableElements = jQuery(modal).find(focusableElementsSelector);
                        firstFocusableElement = focusableElements[0];
                        lastFocusableElement = focusableElements[focusableElements.length - 1];
                    }

                    // Initialize focusable elements when the modal opens
                    setTimeout(function () {
                        updateFocusableElements();
                        firstFocusableElement.focus();
                    }, 1000)

                    jQuery(modal).on('keydown', function (event) {
                        const isTabPressed = (event.key === 'Tab' || event.keyCode === 9);
                        if (!isTabPressed) {
                            return;
                        }

                        if (event.shiftKey) { // Shift + Tab
                            if (document.activeElement === firstFocusableElement) {
                                lastFocusableElement.focus();
                                event.preventDefault();
                            }
                        } else { // Tab
                            if (document.activeElement === lastFocusableElement) {
                                firstFocusableElement.focus();
                                event.preventDefault();
                            }
                        }
                    });


                    const $navigationButton = $('.remodal-inner-container .custom-navigation');

                    // Add a keydown event listener to the button
                    $navigationButton.on('keydown', function (event) {
                        // Check if the Enter key is pressed
                        if (event.key === 'Enter' || event.keyCode === 13) {
                            // Prevent default behavior (optional)
                            //event.preventDefault();

                            const $slideshowRight = $(this).find('.slideshow_right');
                            if ($slideshowRight.length) {
                                $slideshowRight.trigger('click');
                                updateFocusableElements();
                            }
                            const $slideshowLeft = $(this).find('.slideshow_left');
                            if ($slideshowLeft.length) {
                                $slideshowLeft.trigger('click');
                                updateFocusableElements();
                            }
                        }
                    });


                    var start = jQuery('.remodal-inner-container').find('.slideshowdata').data('start')

                    jQuery('.flexslider').animate({opacity: 1}, {duration: 'slow'})
                    jQuery('.flex-container').css('background', 'unset')

                    jQuery('.remodal-story-image').find('#sfi-thumbnails').flexslider({
                        animation: 'slide',
                        controlNav: false,
                        customDirectionNav: jQuery('.remodal-story-image').find('#sfi-thumbnav span'),
                        animationLoop: true,
                        slideshow: false,
                        itemWidth: 106,
                        itemMargin: 5,
                        touch: true,
                        asNavFor: '#sfi-slideshow',
                    })

                    jQuery('.remodal-story-image').find('#sfi-slideshow').flexslider({
                        animation: 'fade',
                        smoothHeight: false,
                        controlNav: false,
                        customDirectionNav: jQuery('.remodal-story-image').find('#sfi-slideshow span'),
                        animationLoop: true,
                        slideshow: false,
                        startAt: start,
                        touch: true,
                        sync: '#sfi-thumbnails',
                    })
                    var thumbAreaWidth = jQuery('.remodal-story-image').find('#sfi-thumbnails').width()
                    var thumbRowWidth = 111 * jQuery('.remodal-story-image').find('#sfi-thumbnails li').length

                    if (thumbRowWidth < thumbAreaWidth) {
                        jQuery('.remodal-story-image').find('.sfi-thumbnails').width(thumbRowWidth)
                    }
                },
            })
        })
    })

    jQuery('body').on('click', '.remodal-story-image div[data-remodal-action="close"]', function () {
        jQuery('.remodal-story-image button.remodal-close').trigger('click')
        sno_slideshow_open = 'no';
        if (photo_overlay_last_focus) {
            jQuery(photo_overlay_last_focus).focus();
        }
        jQuery('a.modal-photo').attr('aria-expanded', 'false')
    })

    jQuery('body').on('click', '.remodal-story-image button.sno-overlay-close', function () {
        sno_slideshow_open = 'no';
        if (photo_overlay_last_focus) {
            jQuery(photo_overlay_last_focus).focus();
        }
        jQuery('a.modal-photo').attr('aria-expanded', 'false')

    })


    // for inline slideshows in stories and widgets

    jQuery(function ($) {

        $('.inline-slideshow-area').on('focus', function () {
            // controlling focus and tabbing in slideshow
            $(this).find('li.storyslide:not(.flex-active-slide)').find('a').attr('tabindex', '-1');
        })


        $('.inline-slideshow-area').each(function () {
            var smooth_height = $(this).find('.flex-container').data('smooth-height')
            var autoscroll_speed = $(this).find('.flex-container').data('autoscroll-speed')
            var autoscroll = $(this).find('.flex-container').data('autoscroll')

            $(this)
                .find('.inline-thumbnails')
                .flexslider({
                    animation: 'slide',
                    controlNav: false,
                    customDirectionNav: $(this).closest('.inline-slideshow-area').find('.inline-thumbnav span'),
                    animationLoop: true,
                    slideshow: false,
                    itemWidth: 107,
                    itemMargin: 1,
                    touch: true,
                    asNavFor: $(this).closest('.inline-slideshow-area').find('.inline-slideshow'),
                })

            $(this)
                .find('.inline-slideshow')
                .flexslider({
                    animation: 'slide',
                    smoothHeight: smooth_height,
                    controlNav: false,
                    slideshowSpeed: autoscroll_speed,
                    slideshow: autoscroll,
                    customDirectionNav: $(this).closest('.inline-slideshow-area').find('.inline-slideshow span'),
                    animationLoop: true,
                    touch: true,
                    sync: $(this).closest('.inline-slideshow-area').find('.inline-thumbnails'),
                })

            $(this)
                .find('.custom-navigation')
                .on('click', function () {
                    return false
                })

            var thumbAreaWidth = $(this).find('.inline-thumbnails').width()
            var thumbRowWidth = 111 * $(this).find('.inline-thumbnails li').length
            if (thumbRowWidth < thumbAreaWidth) {
                $(this).find('.inline-thumbnails').width(thumbRowWidth)
            }

            const $navigationButton = $(this).find('.custom-navigation');
            $navigationButton.on('keydown', function (event) {
                if (event.key === 'Enter' || event.keyCode === 13) {
                    const $slideshowRight = $(this).find('.slideshow_right');
                    if ($slideshowRight.length) {
                        $slideshowRight.trigger('click');
                        $(this).closest('.inline-slideshow-area').find('li.storyslide').find('a').removeAttr('tabindex');
                        $(this).closest('.inline-slideshow-area').find('li.storyslide:not(.flex-active-slide)').find('a').attr('tabindex', '-1');
                    }
                    const $slideshowLeft = $(this).find('.slideshow_left');
                    if ($slideshowLeft.length) {
                        $slideshowLeft.trigger('click');
                        $(this).closest('.inline-slideshow-area').find('li.storyslide').find('a').removeAttr('tabindex');
                        $(this).closest('.inline-slideshow-area').find('li.storyslide:not(.flex-active-slide)').find('a').attr('tabindex', '-1');
                    }
                }
            });

        })
    })

    // activating modal window when sharing button clicked

    jQuery('.modal-share').click(function () {
        if (jQuery(this).hasClass('share-email')) {
            var action = 'shareemail'
        } else {
            var action = 'sharestory'
        }
        jQuery(this).addClass('return-focus-to-div');
        var inst = jQuery('[data-remodal-id=modal-share]').remodal()
        inst.open()

        var sharestoryid = (jQuery(this).find('.email-side-icon').length) ? jQuery(this).find('.email-side-icon').data('story-id') : jQuery(this).data('story-id')

        jQuery.ajax({
            url: frontend_ajax_object.ajaxurl,
            type: 'POST',
            data: {
                action: action,
                sharestoryid: sharestoryid,
            },
            success: function (results) {
                jQuery('.remodal-share-inner-container').replaceWith(results)

                restrictFocusToModal(jQuery('.remodal-share-inner-container').closest('.remodal-wrapper'))

                setTimeout(function () {
                    jQuery('input#human').after(
                        '<div class="sno-email-captcha">Are you a robot or a human? <div class="sno-email-captcha-button sno-email-robot" role="button" aria-pressed="false" tabindex="0"><i class="fas fa-robot"></i><span class="icon-hidden-text">Robot</span></div><div class="sno-captcha-button sno-email-human" role="button" aria-pressed="false" tabindex="0"><i class="fas fa-user"></i><span class="icon-hidden-text">Human</span></button></div>'
                    )
                }, 6000)

                jQuery('body').on('blur focus keypress paste', '.emailstoryform form input', function () {
                    if (jQuery('.sno-email-captcha').is(':hidden') && jQuery('button#submit_email').is(':disabled'))
                        jQuery('.sno-email-captcha').slideDown()
                })
            },
        })
    })

    jQuery('body').on('click', '.remodal-cancel, .remodal-close', function () {
        jQuery('.return-focus-to-div').focus();
    })

    function restrictFocusToModal(container) {
        const modal = jQuery(container);
        const focusableElementsSelector = 'button, input:not([type="hidden"]), textarea, a:not([tabindex="-1"])';
        let firstFocusableElement, lastFocusableElement;

        function updateFocusableElements() {
            // Update first and last focusable elements
            const focusableElements = jQuery(modal).find(focusableElementsSelector);
            firstFocusableElement = focusableElements[0];
            lastFocusableElement = focusableElements[focusableElements.length - 1];
        }

        // Initialize focusable elements when the modal opens
        setTimeout(function () {
            updateFocusableElements();
            firstFocusableElement.focus();
        }, 1000)

        jQuery(modal).on('keydown', function (event) {
            const isTabPressed = (event.key === 'Tab' || event.keyCode === 9);
            if (!isTabPressed) {
                return;
            }

            if (event.shiftKey) { // Shift + Tab
                if (document.activeElement === firstFocusableElement) {
                    lastFocusableElement.focus();
                    event.preventDefault();
                }
            } else { // Tab
                if (document.activeElement === lastFocusableElement) {
                    firstFocusableElement.focus();
                    event.preventDefault();
                }
            }
        });

    }

    // when readers share stories via email

    jQuery(function ($) {
        $('body').on('click', '.sno-email-captcha-button', function (event, wasTriggered) {
            if (wasTriggered) {
                email_robot_click()
            }
        })

        $('body').on('click', '.sno-email-robot', function () {
            email_robot_click()
        })

        function email_robot_click() {
            $('.emailstoryform form button#submit_email').slideUp('slow')
            setTimeout(function () {
                $('.emailstoryform form button#submit_email').remove()
                $('.sno-email-captcha').html('Sorry, only humans are allowed to send email.')
            }, 1000)
        }

        $('body').on('click', '.sno-email-human', function () {
            var r = $('input#wp-remember-email')
            $('.sno-email-captcha').slideUp()
            $('.emailstoryform form button#submit_email').prop('disabled', false)
            setTimeout(function () {
                $('.sno-comment-captcha').remove()
                r.val('1\u200B')
            }, 400)
        })

        $('body').on('focus', '.emailstoryform form input#human', function () {
            set_email_spam_verification()
        })

        function set_email_spam_verification() {
            var z = $('.sno-email-data').data()
            $.each(z, function (x, y) {
                $('.sno-email-data').removeAttr('data-' + x)
            })

            $('input#sno-email-verification').attr('value', '')
            $.each(z, function (a, b) {
                a += ' '
                b += ' '
                $.each(a.split(''), function (c, d) {
                    $('input.sno-email-verification').attr('value', $('input.sno-email-verification').val() + d + b.split('')[c])
                })
            })
            $('input#sno-email-verification').attr('name', 'sno-email-verifyaction')
        }

        $('body').on('input', '.emailstoryform #email_from', function () {
            var val = $(this).val()
            var regexname = /^([a-zA-Z0-9 .@]{1,40})$/
            if (!val.match(regexname)) {
                $(this).addClass('invalid-input')
            } else {
                $(this).removeClass('invalid-input')
            }
        })

        $('body').on('input', '.emailstoryform #email_to', function () {
            var val = $(this).val()
            var email_pattern = /^\b[A-Z0-9._%-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b$/i
            if (val.match(email_pattern)) {
                $(this).removeClass('invalid-input')
            }
        })

        $('body').on('click', '#submit_email', function (e) {
            var email_from_valid = /^([a-zA-Z0-9 .@]{1,20})$/

            if (!$('.emailstoryform #email_from').val().match(email_from_valid)) {
                return
            }

            var email_pattern = /^\b[A-Z0-9._%-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b$/i
            if (!$('.emailstoryform #email_to').val().match(email_pattern)) {
                $('.emailstoryform #email_to').addClass('invalid-input')
                return
            }

            var storyid = $(this).closest('.emailstoryform').data('story-id')
            var humanity = $(this).closest('.emailstoryform').data('humanity')
            var form_data = $(this).closest('form').serializeArray()

            $.ajax({
                url: frontend_ajax_object.ajaxurl,
                type: 'POST',
                data: {
                    action: 'emailstory',
                    storyid: storyid,
                    humanity: humanity,
                    form_data: form_data,
                },
                success: function (results) {
                    $('.remodal-share-inner-container').replaceWith(results)
                },
            })
        })
    })

    // staff page links

    jQuery('tr.staffstoryrow').click(function () {
        var href = jQuery(this).find('a').attr('href')
        if (href) {
            window.location = href
        }
    })

    jQuery('.clickable-row').click(function () {
        window.document.location = jQuery(this).data('href')
    })

    // grid widget -- hover and photo effects

    jQuery('.overlay-hover').mouseenter(function () {
        jQuery(this).find('.gridwidgetoverlay').fadeIn()
        if (jQuery(this).hasClass('enlarge-effect')) {
            jQuery(this).find('img').removeClass('grow')
            jQuery(this).find('img').removeClass('shrink')
            jQuery(this).find('img').addClass('grow')
        }
    })
    jQuery('.overlay-hover').mouseleave(function () {
        jQuery(this).find('.gridwidgetoverlay').fadeOut()
        if (jQuery(this).hasClass('enlarge-effect')) {
            jQuery(this).find('img').addClass('shrink')
        }
    })
    jQuery('body').on('focus', '.grid-widget-tile', function (event) {
        if (event.target != this) return;
        if (jQuery(this).find('a')) jQuery(this).find('a').first().focus();
    })

    jQuery(document).ready(function ($) {
        $('.skip-to-content').on('click', function (e) {
            e.preventDefault();
            var firstFocusableElement = $('#sno-sites-main-content').find('a, button, input, textarea, select, [tabindex]:not([tabindex="-1"])').filter(':visible').first();
            if (firstFocusableElement.length) {
                firstFocusableElement.focus();
            }
        });
    });

    jQuery('.keep-link').click(function () {
        window.location = jQuery(this).find('a').attr('href')
    })

    // carousel widget effects

    jQuery('.carousel-cover-hover').mouseenter(function () {
        jQuery(this).find('.carouseloverlay').fadeIn()
        jQuery(this).find('.carouseloverlaytext').fadeIn()
    })
    jQuery('.carousel-cover-hover').mouseleave(function () {
        jQuery(this).find('.carouseloverlay').fadeOut()
        jQuery(this).find('.carouseloverlaytext').fadeOut()
    })

    jQuery('.carouseltext .continue').click(function () {
        window.location = jQuery(this).parent().find('a.homeheadline').attr('href')
    })

    jQuery('.carousel-cover-hover').click(function () {
        window.location = jQuery(this).find('.widgetheadlineoverlay a').attr('href')
    })

    // category widget
    jQuery('body').on('mouseenter', 'img.enlarge-effect', function () {
        jQuery(this).removeClass('shrink')
        jQuery(this).removeClass('grow')
        jQuery(this).addClass('grow')
    })
    jQuery('body').on('mouseleave', 'img.enlarge-effect', function () {
        jQuery(this).addClass('shrink')
    })

    jQuery('.fw1-textarea .continue').click(function () {
        window.location = jQuery(this).closest('.fw1-panel').find('.widgetheadline a').attr('href')
    })

    jQuery('.fw2-textarea .continue').click(function () {
        window.location = jQuery(this).closest('.fw2-panel').find('.widgetheadline a').attr('href')
    })

    jQuery('.fw3-textarea .continue').click(function () {
        window.location = jQuery(this).closest('.fw3-panel').find('.widgetheadline a').attr('href')
    })

    jQuery('.wa-textarea .continue').click(function () {
        window.location = jQuery(this).closest('.wa-textarea').find('a.homeheadline').attr('href')
    })

    jQuery('.catwidget-col2 .continue').click(function () {
        window.location = jQuery(this).closest('.catwidget-col2').find('a.homeheadline').attr('href')
    })

    // go to top button on long form pages

    jQuery('#gototop').click(function () {
        var bottomPosition = jQuery('.phototop').height()
        var bottomWindow = jQuery(window).height()
        bottomWindow = bottomWindow - 50
        if (bottomWindow < bottomPosition) {
            photoHeight = bottomWindow
            photoHeight = photoHeight - 45
        } else {
            photoHeight = bottomPosition + 35
        }
        jQuery('html, body')
            .animate(
                {
                    scrollTop: jQuery('#mainbody').offset().top - photoHeight,
                },
                1000
            )
            .delay()
        return false
    })

    // side menus on long form pages

    jQuery('#hover-menu').click(function () {
        jQuery('#altheader-searchbox').toggle('slow')
    })

    if (jQuery('.slidemenu').is(':visible')) {
        jQuery('.hidethis').css({visibility: 'hidden'})
        jQuery('#altheader-searchbox').css({zIndex: '1001'})
    } else {
        jQuery('.hidethis').css({visibility: 'visible'})
        jQuery('#altheader-searchbox').css({zIndex: '99'})
    }

    jQuery('.sno-menu').click(function () {
        jQuery('#hoverbar_menu').fadeToggle()
        jQuery('.menu-icon').toggle()
        jQuery('.close-icon').toggle()
        jQuery('#hoverbar_menu').css({height: jQuery(window).height() - 50})
    })

    // comments box and links on story pages

    jQuery('#commentsbox').click(function () {
        jQuery('#commentsbody').slideToggle('slow')
        jQuery('.commenttoggle').toggleClass('fa-plus-square fa-minus-square')
        if (jQuery('.commenttoggle').hasClass('fa-plus-square')) {
            jQuery('.commenttoggle').attr('aria-expanded', 'false')
        } else {
            jQuery('.commenttoggle').attr('aria-expanded', 'true')
        }
    })

    /*
	jQuery("#commentslink, .commentscroll").click(function() {
    	jQuery("#commentsbody").slideDown('slow');
    	jQuery(".commenttoggle").addClass("fa-minus-square").removeClass("fa-plus-square").attr("aria-expanded", "true");
	});
*/

    /*
	jQuery(function($) {
		$('.commentscroll').click(function() {
			var adjustment = 70; // set up a top margin for the scrolled-to element
			if ($(".navbarwrap").hasClass('sno-sticky')) {
				adjustment += jQuery('.navbarwrap').height();
			}
			if ($(".subnavbarwrap").hasClass('sno-sticky')) {
				adjustment += jQuery('.subnavbarwrap').height();
			}
			$('html, body').animate({ scrollTop: $("#commentswrap").offset().top - adjustment }, 500);
			return false;
		});
	});
*/

    // WordPress automatically adjusts widths on left and right floated photos with captions.  It's annoying.  Let's readjust their adjustment.

    // jQuery(document).ready(function () {
    //     jQuery.each(jQuery('.wp-caption'), function () {
    //         jQuery(this).width(jQuery(this).find('img').attr('width'))
    //     })
    // })

    // activate search button on focus within the search box

    jQuery(function () {
        jQuery('.s').focus(function () {
            jQuery('.sno-submit-search-button').prop('disabled', false)
        })
    })

    // Accessibility -- Set tabIndex to -1 so that top_level_links can't receive focus until menu is open

    // var top_level_links = jQuery('.sf-menu').find('> li > a')
    // jQuery(top_level_links).next('ul').find('a').attr('tabIndex', -1)

    // Accessibility -- Adding aria-haspopup for appropriate items

    // jQuery(top_level_links).each(function () {
    //     if (jQuery(this).next('ul').length > 0) jQuery(this).parent('li').attr('aria-haspopup', 'true')
    // })

    // Side menu on mobile view

    jQuery('#hover-menu-side').on('touchstart click', function (e) {
        e.preventDefault()
        jQuery('#sno_mobile_menu').fadeToggle()
        jQuery('body').toggleClass('noscroll')
    })

    jQuery('.side-close-icon').on('touchstart click', function (e) {
        e.preventDefault()
        jQuery('#sno_mobile_menu').fadeToggle()
        jQuery('body').toggleClass('noscroll')
    })

    // Slideshows and photos need to open in remodal overlays -- prevent them from going to a new URL or jumping to anchor

    // jQuery("a[href='#slideshow']").on('click', function (event) {
    //     return false
    // })
    //	jQuery("a[href='#photo']").on('click', function(event) { return false; });

    // Create photo slide up effect as the reader scrolls down the page

    var win = jQuery(window)
    var allMods = jQuery('.sno-animate-active .sno-animate')
    var allWPcaptions = jQuery('.sno-animate-active .wp-caption')

    allMods.each(function (i, el) {
        var el = jQuery(el)
        if (el.is(':visible')) {
            el.addClass('already-visible')
        } else {
            el.css('visibility', 'hidden')
        }
    })
    allWPcaptions.each(function (i, el) {
        var el = jQuery(el)
        if (el.is(':visible')) {
            el.addClass('already-visible')
        }
    })

    jQuery(window).scroll(function (event) {
        jQuery('.sno-animate-active .sno-animate').each(function (i, el) {
            var el = jQuery(el)
            if (el.is(':visible')) {
                el.addClass('come-in')
                el.css('visibility', 'visible')
            }
        })
        jQuery('.sno-animate-active .wp-caption').each(function (i, el) {
            var el = jQuery(el)
            if (el.is(':visible')) {
                el.addClass('come-in')
                el.css('visibility', 'visible')
            }
        })
    })

    // create fade in loading effect for carousels

    jQuery(window).load(function () {
        jQuery('.flexslider').each(function () {
            if (!jQuery(this).hasClass('sno-loading-check')) {
                jQuery('.flexslider').addClass('sno-loading-check')
                jQuery('.flexslider').animate({opacity: 1}, {duration: 'slow'})
                jQuery('.flex-container').css('background', 'unset')
            }
        })
    })
    // Firefox wasn't consistly setting the opacity on window load, so adding these lines as a backup
    jQuery(document).ready(function () {
        setTimeout(function () {
            jQuery('.flexslider').each(function () {
                if (!jQuery(this).hasClass('sno-loading-check')) {
                    jQuery('.flexslider').addClass('sno-loading-check')
                    jQuery('.flexslider').animate({opacity: 1}, {duration: 'slow'})
                    jQuery('.flex-container').css('background', 'unset')
                }
            })
        }, 1000)
    })
    // end Firefox fix

    // jump navigation options when Above Header widget area is activated

    if (jQuery('#upperwrap-outer').is(':visible')) {
        var top_elements = jQuery('#upperwrap-outer').offset().top
        var wp_adminbar = 0
        if (jQuery('#wpadminbar').length > 0) wp_adminbar = jQuery('#wpadminbar').height()

        var jumpbutton = top_elements + 20
        var headerLocation = jQuery('#wrap').offset().top
        if (headerLocation > jQuery(window).height()) {
            jQuery('#jump-to-header')
                .css('top', jumpbutton + 'px')
                .fadeIn()
        }
        jQuery(window).scroll(function () {
            if (jQuery(this).scrollTop() > headerLocation - jQuery(window).height()) {
                jQuery('#jump-to-header').fadeOut()
                jQuery('#jump-arrow').fadeOut()
            } else {
                jQuery('#jump-to-header').fadeIn()
                jQuery('#jump-arrow').fadeIn()
            }
        })

        jQuery('#jump-to-header').click(function () {
            jQuery('html, body').animate({scrollTop: jQuery('#wrap').offset().top - wp_adminbar}, 500)
            return false
        })
        jQuery('#jump-arrow').click(function () {
            jQuery('html, body').animate({scrollTop: jQuery('#wrap').offset().top - wp_adminbar}, 500)
            return false
        })
    }

    // scroll to top functionality on long-form template

    jQuery('#snotop').hide()
    jQuery(function () {
        jQuery(window).scroll(function () {
            if (jQuery(this).scrollTop() > 400) {
                jQuery('#snotop').fadeIn()
            } else {
                jQuery('#snotop').fadeOut()
            }
            if (jQuery(this).scrollTop() > 200) {
                jQuery('.header').fadeIn()
            }
        })

        jQuery('#back-top a').click(function () {
            jQuery('body,html').animate(
                {
                    scrollTop: 0,
                },
                800
            )
            return false
        })
    })

    // immersive image on long-form -- jump to main story

    jQuery(document).ready(function () {
        if (jQuery('#mainbody').is(':visible')) {
            var wp_adminbar = 0
            if (jQuery('#wpadminbar').length > 0) wp_adminbar = jQuery('#wpadminbar').height()

            jQuery('#jump-arrow').click(function () {
                jQuery('html, body').animate({scrollTop: jQuery('#mainbody').offset().top - wp_adminbar}, 500)
                jQuery('#jump-arrow').fadeOut()
                return false
            })

            jQuery(window).scroll(function () {
                if (jQuery(this).scrollTop() > jQuery(window).height()) {
                    jQuery('#jump-arrow').fadeOut()
                } else {
                    jQuery('#jump-arrow').fadeIn()
                }
            })
        }
    })
})

jQuery(document).ready(function () {
    // moving on to other ideas.  Let's hide poll widgets if there are no polls
    jQuery("div:contains('there are no polls available at the moment')").closest('.widgetwrap').hide()
})

// jump navigation on long-form menu

jQuery(document).ready(function () {
    jQuery('li.longform-menu').click(function () {
        var target = jQuery(this).data('part')
        jQuery('html, body').animate({scrollTop: jQuery('#spacer' + target).offset().top}, 500)
        return false
    })
})

jQuery(function ($) {
    $('body').on('click', '.moreheadlines', function () {
        var videoid = $(this).data('video')
        $('#loadingimage').show()
        $('#videowrap').fadeOut()
        $.ajax({
            url: frontend_ajax_object.ajaxurl,
            type: 'POST',
            data: {
                action: 'replace_video',
                type: 'video',
                id: videoid,
            },
            success: function (results) {
                $('#moreposts').replaceWith(results)
                $('#loadingimage').hide()
            },
        })
    })
})

jQuery(document).ready(function () {
    jQuery('body').on('click', '.sno-content-card', function () {
        var href = jQuery(this).find('a').attr('href')
        if (href) {
            window.location = href
        }
    })
})
