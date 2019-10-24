// React
import React from 'react'
import { D3StreamGraph } from './D3StreamGraph';
import { VizOptions } from './VizOptions';

// The number of data points for the chart.
const numDataPoints = 50;

// A function that returns a random number from 0 to 1000
const randomNum = () => Math.floor(Math.random() * 50000);

// A function that creates an array of 50 elements of (x, y) coordinates.
const randomDataSet = () => {
  let data = [];
  for (let i=0; i<30; i++) {
    data.push({'date': new Date(1571832748794 - (30-i)*1000*60*24), 'Pro-vaccine': randomNum(), 'Neutral': randomNum(), 'Anti-vaccine': randomNum()})
  }
  return data;
}


export class StreamGraph extends React.Component {
  // Component was built with the concepts described in this blogpost: http://nicolashery.com/integrating-d3js-visualizations-in-a-react-app/
  // and: https://github.com/freddyrangel/playing-with-react-and-d3
  constructor(props) {
    super(props);
    let windowWidth = window.innerWidth;
    let width;
    if (windowWidth < 576) {
      // mobile
      width = windowWidth - 40;
    } else if (windowWidth < 768) {
      // tablet
      width = 500;
    } else if (windowWidth < 992) {
      width = 560;
    } else if (windowWidth < 1200) {
      width = 600;
    } else {
      // desktop
      width = 720;
    }
    this.state = {
      isLoading: true,
      width: width,
      height: 300,
      activeVizOption: 'wiggle'
    };
    this.colors = ['#68AA43', '#FF9E4B', '#CD5050']; // green, orange, red
  }

  componentDidMount() {
    this.randomizeData();
  }

  randomizeData() {
    this.setState({
      data: randomDataSet(),
      isLoading: false
    });
  }

  onChangeVizOption(option) {
    this.setState({
      activeVizOption: option
    });
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
      body =
        <div className='loading-notification-container'>
          <div className="loading-notification">
            <div className="spinner spinner-with-text"></div>
            <div className='spinner-text'>Loading...</div>
          </div>
        </div>
    } else {
      let keys = this.retrieveKeys(this.state.data);
      body =
        <div>
          <VizOptions
            activeOption={this.state.activeVizOption}
            onChangeOption={(e) => this.onChangeVizOption(e)}
          />
          <D3StreamGraph
            data={this.state.data}
            width={this.state.width}
            height={this.state.height}
            colors={this.colors}
            vizOption={this.state.activeVizOption}
            keys={keys}
          />
        </div>
    }

    return (
      <div id="stream-graph-container" ref={(container) => this.container = container}>
        {body}
      </div>
    )
  }
}
