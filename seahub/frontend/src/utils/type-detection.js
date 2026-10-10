export const getType = (value) => {
  return Object.prototype.toString.call(value).slice(8, -1);
};

/**
 * Check whether is number
 * @param {number} number
 * @returns boolean
 */
export const isNumber = (number) => (number || number === 0) && getType(number) === 'Number';

/**
 * Check whether is object
 * @param {object} object
 * @returns boolean
 */
export const isObject = (object) => object && getType(object) === 'Object';

/**
 * Check whether is string
 * @param {string} string
 * @returns boolean
 */
export const isString = (string) => string && getType(string) === 'String';

/**
 * Check whether is function
 * @param {function} function
 * @returns boolean
 */
export const isFunction = (functionToCheck) => functionToCheck && getType(functionToCheck) === 'Function';
