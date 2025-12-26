function createComponent(title, number) {
    var component = document.createElement('div')
    component.classList.add('sno-countdown-component')
    var header = document.createElement('div')
    header.classList.add('sno-countdown-component-header')
    header.innerHTML = title
    component.append(header)
    var wrap = document.createElement('div')
    wrap.classList.add('sno-countdown-component-numbers')
    component.append(wrap)
    var sNumber = number.toString()
    //if the number is less than 10, show a zero to maintain double-digit appearance
    if (number < 10) {
        let number_component = document.createElement('div')
        number_component.classList.add('sno-countdown-component-number')
        number_component.innerHTML = '0'
        wrap.append(number_component)
    }

    for (let i = 0; i < sNumber.length; i++) {
        let number_component = document.createElement('div')
        number_component.classList.add('sno-countdown-component-number')
        number_component.innerHTML = sNumber.charAt(i)
        wrap.append(number_component)
    }
    return component
}
function updateCountDown(countDownDate, countdownDiv, countDownSeconds) {
    // Get today's date and time
    var now = new Date().getTime()
    // Find the distance between now and the count down date
    var distance = countDownDate - now

    //conditional to hide the countdown and show a completion notification once the date is reached

    if (distance < 0) {
        jQuery(countdownDiv).hide()
        jQuery(countdownDiv).siblings('.sno-countdown-complete').show()
        return
    }

    // Time calculations for days, hours, minutes and seconds
    var days = Math.floor(distance / (1000 * 60 * 60 * 24))
    var hours = Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60))
    var minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60))
    var seconds = Math.floor((distance % (1000 * 60)) / 1000)

    var sno_countdown_container = document.createElement('div')
    sno_countdown_container.classList.add('sno-countdown-container')

    if (days > 0) {
        var component = createComponent('Days', days)
        sno_countdown_container.append(component)
    }
    //this rendering has to happen for each date that is found
    var component = createComponent('Hours', hours)
    sno_countdown_container.append(component)
    var component = createComponent('Minutes', minutes)
    sno_countdown_container.append(component)
    if( countDownSeconds != 'Hide' ) {
        var component = createComponent('Seconds', seconds)
        sno_countdown_container.append(component)
    }
    jQuery(countdownDiv).empty()
    jQuery(countdownDiv).append(sno_countdown_container)
}
initialize_countdown()
function initialize_countdown() {
    jQuery('.sno-countdown').each(function () {
        var countDownDate = new Date(jQuery(this).data('countdown-date')).getTime()
        var countDownDiv = jQuery(this)
        var countDownSeconds = jQuery(this).data('countdown-seconds');
        updateCountDown(countDownDate, countDownDiv, countDownSeconds);
        check_for_three_digits(countDownDiv);
        var x = setInterval(function () {
            updateCountDown(countDownDate, countDownDiv, countDownSeconds);
            check_for_three_digits(countDownDiv);
        }, 1000)
    })
}
function check_for_three_digits(countDownDiv) {
    var tiles = jQuery(countDownDiv).find("div.sno-countdown-component-header:contains('Days')").closest('.sno-countdown-component').find('.sno-countdown-component-numbers div').length
    console.log( tiles )
    if( tiles > 2 ) {
        jQuery(countDownDiv).find("div.sno-countdown-component-header:contains('Days')").closest('.sno-countdown-component').find('.sno-countdown-component-numbers').css('grid-template-columns', 'repeat(' + tiles + ', 1fr)');
    }
}
