{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Main (main) where

import Data.List (sort)
import Data.Maybe (fromMaybe)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Flow
import Monatone.Common (parseMetadata)
import Monatone.Metadata (Metadata (album, artist, title, trackNumber))
import System.Directory.OsPath (listDirectory)
import System.OsPath (OsPath, decodeFS, osp, takeExtension, takeFileName, unsafeEncodeUtf, (</>))

main :: IO ()
main = do
  files <- findMp3Files musicDir
  result <- extractMp3Info files
  case result of
    Left errMsg -> TIO.putStrLn errMsg
    Right mp3Infos -> showResult mp3Infos

findMp3Files :: OsPath -> IO [OsPath]
findMp3Files = subDirectories .> mapM mp3FilesInDirectory .> fmap concat

extractMp3Info :: [OsPath] -> IO (Either T.Text [Mp3Info])
extractMp3Info = mapM parseMp3Info .> fmap sequence

showResult :: [Mp3Info] -> IO ()
showResult mp3Infos =
  mapM formatMp3Info mp3Infos
    >>= mapM_ TIO.putStrLn

formatMp3Info :: Mp3Info -> IO T.Text
formatMp3Info mp3Info = do
  fname <- osPathToTextFS . mp3InfoFileName $ mp3Info
  return $
    T.intercalate
      "\t"
      [ fname,
        mp3InfoAlbum mp3Info,
        T.pack . show . mp3InfoTrackNumber $ mp3Info
      ]

osPathToTextFS :: OsPath -> IO T.Text
osPathToTextFS = decodeFS .> fmap T.pack

musicDir :: OsPath
musicDir = [osp|/mnt/c/Users/vivas/Music|]

subDirectories :: OsPath -> [OsPath]
subDirectories parentPath =
  [parentPath </> dirName n | n <- [1 .. 14]]
  where
    dirName n = unsafeEncodeUtf "メドレー" <> intToOsPath n
    intToOsPath = unsafeEncodeUtf . zeroPad 2 . show
    zeroPad width str = replicate (width - length str) '0' ++ str

mp3FilesInDirectory :: OsPath -> IO [OsPath]
mp3FilesInDirectory path = do
  dirs <- listDirectory path
  dirs
    |> filterMp3
    |> sort
    |> map editAbsPath
    |> return
  where
    hasMp3Ext = takeExtension .> (==) [osp|.mp3|]
    filterMp3 = filter hasMp3Ext
    editAbsPath = (</>) path

parseMp3Info :: OsPath -> IO (Either T.Text Mp3Info)
parseMp3Info path = do
  result <- parseMetadata path
  case result of
    Left _ -> return $ Left "failed to parse mp3"
    Right metadata ->
      Mp3Info
        { mp3InfoFileName = takeFileName path,
          mp3InfoPath = path,
          mp3InfoTitle = fromMaybe "" . title $ metadata,
          mp3InfoArtist = fromMaybe "" . artist $ metadata,
          mp3InfoAlbum = fromMaybe "" . album $ metadata,
          mp3InfoTrackNumber = fromMaybe 0 . trackNumber $ metadata
        }
        |> Right
        |> return

data Mp3Info = Mp3Info
  { mp3InfoFileName :: OsPath,
    mp3InfoPath :: OsPath,
    mp3InfoTitle :: T.Text,
    mp3InfoArtist :: T.Text,
    mp3InfoAlbum :: T.Text,
    mp3InfoTrackNumber :: Int
  }