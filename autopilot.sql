-- phpMyAdmin SQL Dump
-- version 2.6.1-rc1
-- http://www.phpmyadmin.net
-- 
-- Host: localhost
-- Generation Time: Jul 31, 2006 at 07:18 AM
-- Server version: 5.0.22
-- PHP Version: 5.1.4
-- 
-- Database: `autopilot`
-- 

-- --------------------------------------------------------

-- 
-- Table structure for table `chatlog`
-- 

CREATE TABLE IF NOT EXISTS `chatlog` (
  `id` int(10) NOT NULL auto_increment,
  `logtime` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `game` int(10) NOT NULL,
  `log` varchar(255) collate utf8_unicode_ci NOT NULL,
  PRIMARY KEY  (`id`),
  KEY `game` (`game`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

-- 
-- Table structure for table `game`
-- 

CREATE TABLE IF NOT EXISTS `game` (
  `id` int(10) NOT NULL auto_increment,
  `server` int(10) NOT NULL,
  `name` varchar(100) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

-- 
-- Table structure for table `server`
-- 

CREATE TABLE IF NOT EXISTS `server` (
  `id` int(10) NOT NULL auto_increment,
  `name` varchar(100) collate utf8_unicode_ci NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

-- 
-- Table structure for table `setup`
-- 

CREATE TABLE IF NOT EXISTS `setup` (
  `setting` varchar(20) collate utf8_unicode_ci NOT NULL,
  `value` varchar(100) collate utf8_unicode_ci NOT NULL,
  `server` int(10) NOT NULL,
  `logtime` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  PRIMARY KEY  (`setting`,`server`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

-- --------------------------------------------------------

-- 
-- Table structure for table `user`
-- 

CREATE TABLE IF NOT EXISTS `user` (
  `name` varchar(100) collate utf8_unicode_ci NOT NULL,
  `password` varchar(100) collate utf8_unicode_ci NOT NULL,
  PRIMARY KEY  (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
