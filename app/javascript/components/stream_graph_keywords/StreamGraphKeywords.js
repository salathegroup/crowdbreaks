// React
import React from 'react'
import { D3StreamGraph } from './D3StreamGraphKeywords';
import { VizOptions } from './VizOptions';
import { TimeOptions } from './TimeOptions';
import moment from 'moment';


export class StreamGraphKeywords extends React.Component {
  // Component was built with the concepts described in this blogpost: http://nicolashery.com/integrating-d3js-visualizations-in-a-react-app/
  // and: https://github.com/freddyrangel/playing-with-react-and-d3
  constructor(props) {
    super(props);
    let windowWidth = window.innerWidth;
    let width;
    let device = 'desktop';
    if (windowWidth < 576) {
      // mobile
      width = windowWidth - 40;
      device = 'mobile';
    } else if (windowWidth < 768) {
      // tablet
      width = 500;
      device = 'tablet';
    } else if (windowWidth < 992) {
      width = 560;
    } else if (windowWidth < 1200) {
      width = 760;
    } else {
      // desktop
      width = 910;
    }
    this.colors = ['#1e9CeA', '#FF9E4B', '#CD5050', '#68AA43', '#aab8c2']; // green, blue, orange, red
    this.keys = ['China', 'US', 'Japan', 'Thailand', 'Other'];
    this.legendPos = [0, 70, 130, 210, 300];
    this.queries = {'China': ['china'], 'US': ['us'],  'Japan': ['japan'], 'Thailand': ['thailand']}
    this.caption = "Real-time keyword Twitter stream for all content which matches at least one of the keywords \"ncov\", \"wuhan\", or \"coronavirus\". Tracking started in January 13, 2020. Keywords matching shows subset which uniquely match one of the keywords. Y-axis shows counts per hour (for 1m option counts are per day)."
    this.momentTimeFormat = 'YYYY-MM-DD HH:mm:ss'
    this.state = {
      isLoading: true,
      width: width,
      height: 300,
      activeVizOption: 'zero',
      errorNotification: '',
      useTransition: false,
      timeOption: '2',
      device: device,
      cachedData: {}
    };
  }

  componentDidMount() {
    const options = this.getTimeOption(this.state.timeOption)
    this.getData(options);
  }

  getTimeOption(option) {
    let interval, startDate, endDate;
    switch(option) {
      case '1':
        interval = 'day'
        endDate = moment.utc().startOf(interval)
        startDate = endDate.clone().subtract(1, 'month')
        break;
      case '2':
        interval = 'hour'
        endDate = moment.utc().startOf(interval)
        startDate = endDate.clone().subtract(10, 'days')
        break;
      case '3':
        interval = 'hour'
        endDate = moment.utc().startOf(interval)
        startDate = endDate.clone().subtract(1, 'day')
        break;
    }
    // avoid first interval of endDate
    endDate.subtract(1, 'second')
    return {
      interval: interval,
      start_date: startDate.format(this.momentTimeFormat),
      end_date: endDate.format(this.momentTimeFormat),
      timeOption: option,
      es_index_name: this.props.es_index_name,
      queries: this.queries
    }
  }

  getData(options) {
    // check if data has been previously loaded
    if (options.timeOption in this.state.cachedData) {
      const newData = this.state.cachedData[options.timeOption];
      this.setState({
        data: newData,
        isLoading: false,
        useTransition: false,
        timeOption: options.timeOption
      });
      return
    }
    const params = {
      viz: options
    };
    $.ajax({
      beforeSend: function(xhr) {xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'))},
      type: "POST",
      crossDomain: true,
      url: this.props.dataEndpoint,
      data: JSON.stringify(params),
      dataType: "json",
      contentType: "application/json",
      success: (result) => {
        console.log(result);
        const arrayLengths = this.keys.map((key) => result[key].length)
        const maxLengthKey = this.keys[arrayLengths.indexOf(Math.max(...arrayLengths))]
        let data = [];
        let counters = {};
        this.keys.forEach((key) => {
          counters[key] = 0;
        });

        for (let i=0; i < result[maxLengthKey].length; i++) {
          let d = {'date': new Date(moment.utc(result[maxLengthKey][i].key_as_string))}
          this.keys.forEach((key) => {
            if (result[key][counters[key]] && result[key][counters[key]].key_as_string === result[maxLengthKey][i].key_as_string) {
              let doc_count = result[key][counters[key]].doc_count;
              if (doc_count === 'null') {
                d[key] = 0;
              } else {
                d[key] = doc_count;
              }
              counters[key] += 1;
            } else {
              d[key] = 0;
            }
          });
          data.push(d);
        }
        if (data.length == 0) {
          this.setState({
            errorNotification: "Something went wrong when trying to load the data. Sorry ¯\\_(ツ)_/¯"
          })
          return
        }
        // pad data with zeroes in the beginning and end of the range (if data is missing)
        const startDaterange = this.daterange(moment.utc(options.start_date), moment(data[0].date), options.interval);
        let padZeroes = {}
        this.keys.forEach((key) => {
          padZeroes[key] = 0;
        })
        for (let i=startDaterange.length-1; i >= 0; i--) {
          const d = {date: startDaterange[i], ...padZeroes}
          data.unshift(d)
        }
        const endDaterange = this.daterange(moment(data.slice(-1)[0].date), moment.utc(options.end_date).subtract(1, options.interval), options.interval);

        for (let i=0; i < endDaterange.length; i++) {
          const d = {date: endDaterange[i], ...padZeroes}
          data.push(d)
        }
        let cachedData = this.state.cachedData;
        cachedData[options.timeOption] = data;
        this.setState({
          data: data,
          isLoading: false,
          useTransition: false,
          timeOption: options.timeOption,
          cachedData: cachedData
        });
      }
    });
  }

  daterange(startDate, stopDate, frequency='hour') {
    var dateArray = [];
    var currentDate = startDate;
    while (currentDate < stopDate) {
      dateArray.push(new Date(currentDate))
      currentDate = moment(currentDate).add(1, frequency);
    }
    return dateArray;
  }

  onChangeVizOption(option) {
    this.setState({
      activeVizOption: option,
      useTransition: true
    });
  }

  onChangeTimeOption(option) {
    const options = this.getTimeOption(option)
    this.setState({
      isLoading: true
    })
    this.getData(options)
  }

  retrieveKeys(data) {
    let keys = [];
    if (this.state.data.length > 0) {
        keys = Object.keys(this.state.data[0]);
        keys = keys.filter(item => item !== 'date')
      }
    return keys;
  }

  render() {
    let body;
    if (this.state.isLoading) {
      if (this.state.errorNotification == '') {
        body =
          <div className='loading-notification-container'>
            <div className="loading-notification">
              <div className="spinner spinner-with-text"></div>
              <div className='spinner-text'>Loading...</div>
            </div>
          </div>
      } else {
        body = <div className='loading-notification-container'>
          <div className="alert alert-primary">
              {this.state.errorNotification}
          </div>
        </div>
      }
    } else {
      let keys = this.retrieveKeys(this.state.data);
      body =
        <div>
          <div className='stream-graph-btn-group'>
            <TimeOptions
              timeOption={this.state.timeOption}
              onChangeOption={(e) => this.onChangeTimeOption(e)}
            />
              <VizOptions
                activeOption={this.state.activeVizOption}
                onChangeOption={(e) => this.onChangeVizOption(e)}
              />
          </div>
          <D3StreamGraph
            data={this.state.data}
            width={this.state.width}
            height={this.state.height}
            colors={this.colors}
            legendPos={this.legendPos}
            vizOption={this.state.activeVizOption}
            useTransition={this.state.useTransition}
            keys={keys}
            device={this.state.device}
          />
          <div className="mt-5 text-light">
            {this.caption}
          </div>
        </div>
    }

    return (
      <div id="stream-graph-container" ref={(container) => this.container = container}>
        {body}
      </div>
    )
  }
}