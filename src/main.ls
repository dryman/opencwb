_ = require \underscore

@include = ->
    cwb = require \cwbtw
    @use \bodyParser, @app.router, @express.static __dirname + \/../_public

    Schema = @mongoose.Schema
    ForecastSchema = new Schema do
        issued:  Date
        time: Date
        area: String
        forecast: do
            PoP:    Number

    LastUpdatedSchema = new Schema do
        key: String
        time: Date
    RealBin = require \path .dirname do
        require \fs .realpathSync __filename
    RealBin -= /\/src/
    Forecast = @mongoose.model \Forecast, ForecastSchema
    LastUpdated = @mongoose.model \LastUpdated, LastUpdatedSchema

    LastUpdated.findOne { key: \72hr-forecast }, (err, last) ~>
        @last = last.time

    sendFile = (file) -> ->
        @response.contentType \text/html
        @response.sendfile "#RealBin/_public/#file"

    JsonType = { \Content-Type : 'application/json; charset=utf-8' }

    forecast_for = (area, cb) ~>
        Forecast.find { area, issued: @last }
            .sort \time
            .exec (err, results) ->
                cb err, [ {area,issued,time,forecast} for {area,issued,time,forecast} in results]

    get_area = (cb) ~>
        cb null, _.values cwb.cwbspec

    @set databag: \param
    @get '/1/forecast/:area': (p) ->
        err, results <~ forecast_for p.area
        @response.send JSON.stringify(results), JsonType, 200

    @get '/1/area': (p) ->
        err, results <~ get_area
        @response.send JSON.stringify(results), JsonType, 200

    cache = {}
    @get '/1/typhoon/jtwc/:name': (p) ->
        if results = cache[p.name]
            return @response.send JSON.stringify(results), JsonType, 200

        error, {statusCode}, body <~ (require \request) "http://jtwccdn.appspot.com/NOOC/nmfc-ph/RSS/jtwc/warnings/#{p.name}.tcw"
        paths = []
        past = []
        lines = body.split("\n")map (it) -> it - /\s*$/
        [,,issued] = lines.shift!split " "
        for line in lines when date = line.match /^(\d\d\d\d)(\d\d)(\d\d)(\d\d) /
            if name
                past.push line
            else
                issued = date[0]
                [year, month, day, hour] = date[1 to 4]
                [,,name] = line.split(" ")
        for line in lines
            if line.match(/^T/)
                paths.push line
            break if line == 'AMP'
        cache[p.name] = results = { name, paths, issued, past }
        @response.send JSON.stringify(results), JsonType, 200

    @get '/:what': sendFile \index.html
