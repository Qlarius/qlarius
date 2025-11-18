//function to hide and display
jQuery(document).ready(function ($) {
    $('body').on('click', '.sno-weather-daily-button-off', function () {
        $(this).closest('.widgetwrap').find('.sno-weather-extended-forecast-container').show('slow')
        $(this).closest('.widgetwrap').find('.sno-weather-hourly-container').hide()

        $(this).closest('.widgetwrap').find('.sno-weather-daily-button').removeClass('sno-weather-daily-button-off')
        $(this).closest('.widgetwrap').find('.sno-weather-daily-button').addClass('sno-weather-daily-button-on')
        $(this).closest('.widgetwrap').find('.sno-weather-hourly-button').removeClass('sno-weather-hourly-button-on')
        $(this).closest('.widgetwrap').find('.sno-weather-hourly-button').addClass('sno-weather-hourly-button-off')
    })

    $('body').on('click', '.sno-weather-hourly-button-off', function () {
        $(this).closest('.widgetwrap').find('.sno-weather-extended-forecast-container').hide()
        $(this).closest('.widgetwrap').find('.sno-weather-hourly-container').show('slow')

        $(this).closest('.widgetwrap').find('.sno-weather-hourly-button').removeClass('sno-weather-hourly-button-off')
        $(this).closest('.widgetwrap').find('.sno-weather-hourly-button').addClass('sno-weather-hourly-button-on')
        $(this).closest('.widgetwrap').find('.sno-weather-daily-button').removeClass('sno-weather-hourly-button-on')
        $(this).closest('.widgetwrap').find('.sno-weather-daily-button').addClass('sno-weather-daily-button-off')
    })
})
