import React from 'react';
import PropTypes from 'prop-types';
import Icon from '../icon';

import './index.css';

function CustomizeAddTool({ callBack, name, className }) {
  return (
    <div className={`customize-add-tool ${className || ''}`} onClick={(e) => {e.stopPropagation(); callBack(e);}}>
      <Icon symbol="plus" className="customize-add-tool-icon" />
      <span className="text-truncate" title={name} aria-label={name}>{name}</span>
    </div>
  );
}

CustomizeAddTool.propTypes = {
  className: PropTypes.string,
  name: PropTypes.string.isRequired,
  callBack: PropTypes.func.isRequired,
};

export default CustomizeAddTool;
